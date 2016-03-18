#include <Timer.h>
#include "FireSensor.h"
#include <printf.h>
#include <stdlib.h>

module FireSensorC {
  uses interface Boot;
  uses interface Timer<TMilli> as TimerGps;
  uses interface Timer<TMilli> as TimerData;
  uses interface Timer<TMilli> as TimerSmoke;

  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface SplitControl as AMControl;

  uses interface Receive;
}

implementation {
  //listas dos sensornodes do routing node
  uint16_t sensorList[MAX_NUMBER_OF_SENSORS];

  //lista dos sensornodes que têm as coord GPS no logfile.
  uint16_t gpsList[MAX_NUMBER_OF_SENSORS];

  //lista com as mensagens ja re-enviadas.
  History cacheList[NUMBER_OF_MESSAGES];

  uint16_t smokeList[MAX_NUMBER_OF_SENSORS];

  //lista dos sensornodes que têm as coord GPS no logfile.
  uint16_t renegatedList[MAX_NUMBER_OF_SENSORS];

  //lista de controlo do relay de msgs gps com capacidade para todos os sensores na floresta
  GpsMsgControl gpsControlList[MAX_NUMBER_OF_SENSORS];

  //lista com as routing messages ja enviadas
  RoutingMsgControl routingControlList[NUMBER_OF_MESSAGES];

  SmokeMsgControl smokeControlList[NUMBER_OF_MESSAGES];


  uint16_t sensorIndex = 0;
  uint16_t gpsIndex = 0;
  uint16_t renegatedIndex = 0;
  uint16_t smokeIndex = 0;
  uint16_t cacheIndex = 0;
  uint16_t messageId = 0;
  uint16_t gpsControlIndex = 0;
  uint16_t routingControlIndex = 0;
  uint16_t smokeControlIndex = 0;
  uint16_t x;
  uint16_t y;
  uint16_t gpsPacket = 0;
  bool busy = FALSE;
  bool alreadyReceived = FALSE;
  bool alreadyWrited = FALSE;
  bool gpsCounted = FALSE;
  bool routingCounted = FALSE;
  bool smokeCounted = FALSE;
  message_t pkt;

  event void Boot.booted(){
    x = rand() % 100;
    y = rand() % 100;
    dbg("Boot, FireSensorC", "Application Booted\n");
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err){
    if (err == SUCCESS){
      if(TOS_NODE_ID > 99){  //sensor node

        //mandar as coordenadas GPS
        call TimerGps.startPeriodic(GPS_PERIOD_MILLI);

        //mandar os dados
        call TimerData.startPeriodic(DATA_PERIOD_MILLI);

        //alerta smoke
        call TimerSmoke.startPeriodic(SMOKE_PERIOD_MILLI);
      }
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err){
  }
 
  event void TimerGps.fired(){
    if(!busy){
      GPSMsg* gpsPkt = (GPSMsg*)(call Packet.getPayload(&pkt, sizeof (GPSMsg)));
      gpsPkt->nodeid = TOS_NODE_ID;
      gpsPkt->x = x;
      gpsPkt->y = y;
      
      if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(GPSMsg)) == SUCCESS){
        dbg("FireSensorC", "GPS MSG SENT: %hu %hu %hu\n", gpsPkt->nodeid, gpsPkt->x, gpsPkt->y);
        busy = TRUE;
      }
    }
  }

  event void TimerData.fired(){
    messageId++;

    if(!busy) {
      DataMsg* dataPkt = (DataMsg*)(call Packet.getPayload(&pkt, sizeof (DataMsg)));
      dataPkt->nodeid = TOS_NODE_ID;
      dataPkt->messageid = messageId;
      dataPkt->humidity = rand() % 100;
      dataPkt->temperature = rand() % 50;

      if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(DataMsg)) == SUCCESS){
       dbg("FireSensorC", "DATA MSG SENT: %hu %hu %hu %hu\n", dataPkt->nodeid, dataPkt->messageid, dataPkt->humidity, dataPkt->temperature);
       busy = TRUE;
      }
    }
  }

  event void TimerSmoke.fired(){

    if((rand() % 75) == 1){
      if(!busy) {
        SmokeMsg* smokePkt = (SmokeMsg*)(call Packet.getPayload(&pkt, sizeof (SmokeMsg)));
        smokePkt->nodeid = TOS_NODE_ID;
        smokePkt->routingid = 0;

        if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(SmokeMsg)) == SUCCESS){
         dbg("FireSensorC", "SMOKE MSG SENT: %hu %hu\n", smokePkt->nodeid, smokePkt->routingid);
         busy = TRUE;
        }
      }
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t error){
    busy = FALSE;
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
    FILE* logFile;
    uint16_t i;

    //mensagem GPS
    if(len == sizeof(GPSMsg)){
      GPSMsg* gpsPkt = (GPSMsg*)payload;

      if(TOS_NODE_ID > 0 && TOS_NODE_ID < 100){ //routing node
        dbg("FireSensorC", "ROUTING NODE RECEIVED GPS MSG: SensorID: %hu x: %hu y: %hu\n", gpsPkt->nodeid, gpsPkt->x, gpsPkt->y);

        //reiniciar renegated list
        gpsPacket++;
        if(gpsPacket == 6){
          dbg("FireSensorC", "ROUTING NODE RESET RENEGATED LIST\n");
          for(i = 0; i < MAX_NUMBER_OF_SENSORS; i++){
            renegatedList[i] = -1;
          }    
          renegatedIndex = 0;
          gpsPacket = 0;
        }

        //se o msg ja tiver sido enviada, vemos quantas vezes, se exceder o máximo, não enviamos mais
        for(i = 0; i < MAX_NUMBER_OF_SENSORS; i++){
          if(gpsControlList[i].nodeid == gpsPkt->nodeid){
            if(gpsControlList[i].counter > MAX_GPS_RELAY)
              return msg;
            else break;
          }
        }
        
        if(!busy){
          if(call AMSend.send(AM_BROADCAST_ADDR, msg, sizeof(GPSMsg)) == SUCCESS){

            //se a msg existir na lista incremento o contador
            for(i = 0; i < MAX_NUMBER_OF_SENSORS; i++){
              if(gpsControlList[i].nodeid == gpsPkt->nodeid){
                gpsControlList[i].counter += 1;
                gpsCounted = TRUE; 
                break;
              }
            }

            //cc adiciono á lista
            if(!gpsCounted){
              gpsControlList[gpsControlIndex].nodeid = gpsPkt->nodeid;
              gpsControlList[gpsControlIndex].counter = 1;
              gpsControlIndex++;
            }
            gpsCounted = FALSE;

            //adicionar a msg á lista
            
            dbg("FireSensorC", "ROUTING NODE RESENT GPS MSG SensorID: %hu x: %hu y: %hu\n", gpsPkt->nodeid, gpsPkt->x, gpsPkt->y);
            busy = TRUE;
          }
        }
      }
      else 
        if(TOS_NODE_ID == 0){ //server node
          dbg("FireSensorC", "SERVER NODE RECEIVED GPS MSG: SensorID: %hu x: %hu y: %hu\n", gpsPkt->nodeid, gpsPkt->x, gpsPkt->y);

          for(i = 0; i < MAX_NUMBER_OF_SENSORS; i++){
            //se ja recebi a mensagem não faço nada
            if(gpsPkt->nodeid == gpsList[i]){
              alreadyReceived = TRUE;
              break;
            }
          }

          //cc vou escrever no log
          if(!alreadyReceived){
            logFile = fopen("gps.txt", "a");
            dbg("FireSensorC", "SERVER NODE WRITED TO LOG GPS MSG: SensorID: %hu x: %hu y: %hu\n", gpsPkt->nodeid, gpsPkt->x, gpsPkt->y);
            fprintf(logFile, "GPS: SensorID: %hu x: %hu y: %hu\n", gpsPkt->nodeid, gpsPkt->x, gpsPkt->y);
            fclose(logFile);


            //e actualizo a mensagem na lista
            gpsList[gpsIndex] = gpsPkt->nodeid;
            gpsIndex++;        
          }
          alreadyReceived = FALSE;
        }
    }

    //mensagem de dados
    if(len == sizeof(DataMsg)){
      DataMsg* dataPkt = (DataMsg*)payload;
      
      if(TOS_NODE_ID > 0 && TOS_NODE_ID < 100){ //routing node
        dbg("FireSensorC", "ROUTING NODE RECEIVED DATA MSG: %hu %hu %hu %hu\n", dataPkt->nodeid, dataPkt->messageid, dataPkt->humidity, dataPkt->temperature);
        
        //verificar se o sensornode está na lista dos renegados
        for(i = 0; i < MAX_NUMBER_OF_SENSORS; i++){
          if(dataPkt->nodeid == renegatedList[i]){
            dbg("FireSensorC", "NOT MINE IGNORE: %hu\n", dataPkt->nodeid);
            return msg;
          }
        }        

        //se o sensor for meu, entao faço propaganda
        for(i = 0; i < MAX_NUMBER_OF_SENSORS; i++){
          if(dataPkt->nodeid == sensorList[i]){
            if(!busy) {
              RoutingMsg* routingPkt = (RoutingMsg*)(call Packet.getPayload(&pkt, sizeof (RoutingMsg)));
              routingPkt->sensorMessage = *dataPkt;
              routingPkt->routingid = TOS_NODE_ID;

              //manda uma msg aos outros routing nodes a reclamar o sensor node
              if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(RoutingMsg)) == SUCCESS){
               dbg("FireSensorC", "ALREADY MINE AND BROADCAST: SensorID: %hu mid: %hu rid: %hu\n", routingPkt->sensorMessage.nodeid, routingPkt->sensorMessage.messageid, routingPkt->routingid);
               busy = TRUE;
              }
              return msg;
            }
          }
        }

        //se o sensor não for meu, tento ficar com ele
        for(i = 0; i < MAX_NUMBER_OF_SENSORS; i++){
          if(sensorList[i] == -1){
            sensorList[i] = dataPkt->nodeid;
            if(!busy){
              RoutingMsg* routingPkt = (RoutingMsg*)(call Packet.getPayload(&pkt, sizeof (RoutingMsg)));
              routingPkt->sensorMessage = *dataPkt;
              routingPkt->routingid = TOS_NODE_ID;

              if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(RoutingMsg)) == SUCCESS){
               dbg("FireSensorC", "TAKING NODE AND BROADCAST: SensorID: %hu mid: %hu rid: %hu\n", routingPkt->sensorMessage.nodeid, routingPkt->sensorMessage.messageid, routingPkt->routingid);
               busy = TRUE;
              }
              return msg;
            }    
          }
        }

        //a lista n tem posições vazias, logo adicionamos na ultima posição livre.
        sensorList[sensorIndex] = dataPkt->nodeid;
        sensorIndex++;

        if(!busy) {
          RoutingMsg* routingPkt = (RoutingMsg*)(call Packet.getPayload(&pkt, sizeof (RoutingMsg)));
          routingPkt->sensorMessage = *dataPkt;
          routingPkt->routingid = TOS_NODE_ID;

          if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(RoutingMsg)) == SUCCESS){
            dbg("FireSensorC", "TAKING NODE AND BROADCAST: SensorID: %hu mid: %hu rid: %hu\n", routingPkt->sensorMessage.nodeid, routingPkt->sensorMessage.messageid, routingPkt->routingid);
            busy = TRUE;
          }
          return msg;
        }
      }
    }

    //mensagem de routing
    if(len == sizeof(RoutingMsg)){
      RoutingMsg* routingPkt = (RoutingMsg*)payload;

      if(TOS_NODE_ID > 0 && TOS_NODE_ID < 100){ //routing node
        dbg("FireSensorC", "ROUTING NODE RECEIVED ROUTING MSG: SensorId: %hu MessageId: %hu RoutingId: %hu\n", routingPkt->sensorMessage.nodeid, routingPkt->sensorMessage.messageid, routingPkt->routingid);

        //se fui eu que mandei a mensagem, ignoro
        if(TOS_NODE_ID == routingPkt->routingid){
          dbg("FireSensorC", "I ALREADY SENT THAT MESSAGE, SO IGNORE IT: SensorId: %hu MessageId: %hu RoutingId: %hu\n", routingPkt->sensorMessage.nodeid, routingPkt->sensorMessage.messageid, routingPkt->routingid);
          return msg;
        }

        for(i = 0; i < MAX_NUMBER_OF_SENSORS; i++){
          if(routingPkt->sensorMessage.nodeid == renegatedList[i]){
            if(!busy){
              if(call AMSend.send(AM_BROADCAST_ADDR, msg, sizeof(RoutingMsg)) == SUCCESS){
                dbg("FireSensorC", "ROUTING NODE IGNORED ROUTING MESSAGE: SensorId: %hu MessageId: %hu RoutingId: %hu\n", routingPkt->sensorMessage.nodeid, routingPkt->sensorMessage.messageid, routingPkt->routingid);
                busy = TRUE;
                return msg;
              }
            }
          }
        }

        //verificar se o sensornode está na nossa lista de sensores
        for(i = 0; i < MAX_NUMBER_OF_SENSORS; i++){
          if(routingPkt->sensorMessage.nodeid == sensorList[i]){
            dbg("FireSensorC", "SensorID COLISION: %hu\n", routingPkt->sensorMessage.nodeid);
            
            //se eu tiver menos prioridade que o outro routing node, apago e faço add á lista dos renegated
            if(TOS_NODE_ID > routingPkt->routingid){
              dbg("FireSensorC", "REMOVING FROM LIST ID: %hu\n", routingPkt->sensorMessage.nodeid);
              sensorList[i] = -1;
              renegatedList[renegatedIndex] = routingPkt->sensorMessage.nodeid;
              renegatedIndex++;
            }
            break;
          }
        }

        //paramos de mandar a mensagem
        for(i = 0; i < NUMBER_OF_MESSAGES; i++){
          if(routingControlList[i].messageid == routingPkt->sensorMessage.messageid && routingControlList[i].sensorid == routingPkt->sensorMessage.nodeid){
            if(routingControlList[i].counter > MAX_ROUTING_RELAY){
              dbg("FireSensorC", "ROUTING NODE CANT RELAY THIS MESSAGE ANYMORE: SensorID: %hu MessageID: %hu\n", routingPkt->sensorMessage.nodeid, routingPkt->sensorMessage.messageid);
              return msg;
            }
            else break;
          }
        }

        if(!busy){
          if(call AMSend.send(AM_BROADCAST_ADDR, msg, sizeof(RoutingMsg)) == SUCCESS){
            dbg("FireSensorC", "ROUTING NODE RESENT ROUTING MESSAGE: SensorId: %hu MessageId: %hu RoutingId: %hu\n", routingPkt->sensorMessage.nodeid, routingPkt->sensorMessage.messageid, routingPkt->routingid);
            busy = TRUE;

            //se a msg existir na lista incremento o contador
            for(i = 0; i < NUMBER_OF_MESSAGES; i++){
              if(routingControlList[i].messageid == routingPkt->sensorMessage.messageid && routingControlList[i].sensorid == routingPkt->sensorMessage.nodeid){
                routingControlList[routingControlIndex].counter += 1;
                routingCounted = TRUE; 
                break;
              }
            }

            //cc adiciono á lista
            if(!routingCounted){
              routingControlList[routingControlIndex].messageid = routingPkt->sensorMessage.messageid;
              routingControlList[routingControlIndex].sensorid = routingPkt->sensorMessage.nodeid;
              routingControlList[routingControlIndex].counter = 1;
              routingControlIndex++;
            }
            routingCounted = FALSE;
          }
        }
      }

      if(TOS_NODE_ID == 0){ //server node
          dbg("FireSensorC", "SERVER NODE RECEIVED ROUTING MESSAGE: SensorId: %hu MessageId: %hu RoutingId: %hu\n", routingPkt->sensorMessage.nodeid, routingPkt->sensorMessage.messageid, routingPkt->routingid);
          for(i = 0; i < NUMBER_OF_MESSAGES; i++){
            //se ja escrevi a msg no logfile
            if(cacheList[i].nodeid == routingPkt->sensorMessage.nodeid && cacheList[i].messageid == routingPkt->sensorMessage.messageid){
              alreadyWrited = TRUE;
              break;
            }
          }

          if(!alreadyWrited){
            logFile = fopen("log.txt", "a");
            fprintf(logFile, "Timestamp: %hu SensorID: %hu MessageId: %hu Humidity: %hu Temperature: %hu\n", call TimerData.getNow(), routingPkt->sensorMessage.nodeid, routingPkt->sensorMessage.messageid, routingPkt->sensorMessage.humidity, routingPkt->sensorMessage.temperature);
            fclose(logFile);

            cacheList[cacheIndex].nodeid = routingPkt->sensorMessage.nodeid;
            cacheList[cacheIndex].messageid = routingPkt->sensorMessage.messageid;
            cacheIndex++;        
          }
          alreadyWrited = FALSE;
        }
    }

    //mensagem de fumo
    if(len == sizeof(SmokeMsg)){
      SmokeMsg* smokePkt = (SmokeMsg*)payload;

      if(TOS_NODE_ID > 0 && TOS_NODE_ID < 100){ //routing node
        dbg("FireSensorC", "ROUTING NODE RECEIVED SMOKE MSG: SensorID: %hu %hu\n", smokePkt->nodeid, smokePkt->routingid);

        //se fui eu que mandei a mensagem, ignoro
        if(TOS_NODE_ID == smokePkt->routingid){
          dbg("FireSensorC", "I ALREADY SENT THAT MESSAGE, SO IGNORE IT: SensorID: %hu %hu\n", smokePkt->nodeid, smokePkt->routingid);
          return msg;
        }

        for(i = 0; i < NUMBER_OF_MESSAGES; i++){
          if(smokeControlList[i].nodeid == smokePkt->nodeid){
            if(smokeControlList[i].counter > MAX_SMOKE_RELAY){
              dbg("FireSensorC", "ROUTING NODE CANT RELAY THIS MESSAGE ANYMORE: SensorID: %hu %hu\n", smokePkt->nodeid, smokePkt->routingid);
              return msg;
            }
            else break;
          }
        }

        //espalha a mensagem
        if(!busy){
          if(smokePkt->routingid == 0)
            smokePkt->routingid = TOS_NODE_ID;
          if(call AMSend.send(AM_BROADCAST_ADDR, msg, sizeof(SmokeMsg)) == SUCCESS){
            dbg("FireSensorC", "ROUTING NODE RESENT SMOKE MSG: SensorID: %hu %hu\n", smokePkt->nodeid, smokePkt->routingid);
            busy = TRUE;

            //se a msg existir na lista incremento o contador
            for(i = 0; i < NUMBER_OF_MESSAGES; i++){
              if(smokeControlList[i].nodeid == smokePkt->nodeid){
                smokeControlList[smokeControlIndex].counter += 1;
                smokeCounted = TRUE; 
                break;
              }
            }

            //cc adiciono á lista
            if(!smokeCounted){
              smokeControlList[smokeControlIndex].nodeid = smokePkt->nodeid;
              smokeControlList[smokeControlIndex].counter = 1;
              smokeControlIndex++;
            }
            smokeCounted = FALSE;
          }
        }
      }

      if(TOS_NODE_ID == 0){ //server node
        dbg("FireSensorC", "SERVER NODE RECEIVED ALERT MESSAGE: SensorId: %hu %hu\n", smokePkt->nodeid, smokePkt->routingid);

        for(i = 0; i < NUMBER_OF_MESSAGES; i++){
          //se ja escrevi a msg no logfile
          if(smokeList[i] == smokePkt->nodeid){
            alreadyWrited = TRUE;
            break;
          }
        }

        if(!alreadyWrited){
          logFile = fopen("log.txt", "a");
          fprintf(logFile, "Timestamp: %hu SensorID: %hu !!!SMOKE ALERT!!!\n", call TimerData.getNow(), smokePkt->nodeid);
          fclose(logFile);

          smokeList[smokeIndex] = smokePkt->nodeid;
          smokeIndex++;        
        }
        alreadyWrited = FALSE;
      } 
    }
    return msg;
  }
}