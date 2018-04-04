import { Component, OnInit } from '@angular/core';
import { pendingSessions } from '../../models/pendingSessions.model';
import { PendingSessionsService } from '../../services/pending-sessions.service';

@Component({
  selector: 'app-pending-sessions',
  templateUrl: './pending-sessions.component.html',
  styleUrls: ['./pending-sessions.component.css']
})
export class PendingSessionsComponent implements OnInit {
  
  private pendingSessions:Array<pendingSessions>;
  private amountItems=4; //amount of items per page
  private pageNumberTwo=1; //current page
  private playerId;

  constructor(private pendingSessionService:PendingSessionsService) { 
    let playerIdLevel=JSON.parse(localStorage.getItem("playerInformation"));
    this.playerId=playerIdLevel.o_playerId;
    this.getSessions();

  }


  public setPendingSessions(dataArray:Array<any>){
    let size= dataArray.length;
    let i=0;
    this.pendingSessions=new Array<pendingSessions>();

    for(i=0; i< size;i++){
      this.pendingSessions.push(new pendingSessions(dataArray[i].o_sessionID,
        dataArray[i].o_enemyName,dataArray[i].o_amountGames,dataArray[i].o_boardSize,
        dataArray[i].o_numberActualGame));

    }
  }

  public getPendingSessions(playerId:Number){
    this.pendingSessionService.getPendingSessions(playerId)
      .subscribe(
        (res) =>{
            this.setPendingSessions(res);
        },
        (err) => {
          console.log(err.json()); 
        });
  }

  public getSessions(){
    let id = setInterval(() => {
      this.getPendingSessions(this.playerId);
  }, 10000);

  }

  public restartSession(sessionId:Number){
    alert("Id de la sesión: "+ sessionId);
    localStorage.setItem("sessionData",JSON.stringify({"sessionId":sessionId,"playerId":this.playerId}));
    window.location.href='gameModule';
  }

  ngOnInit() {
  }

}
