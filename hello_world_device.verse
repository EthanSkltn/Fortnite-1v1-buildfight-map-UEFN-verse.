using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Fortnite.com/Game}
using { /Fortnite.com/Characters}
using { /Fortnite.com/Playspaces }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/UI }
using { /Fortnite.com }
using { /Verse.org/Colors }
using {/Fortnite.com/FortPlayerUtilities}

#TODO
#When player leaves game player kills reset
#Display kills on start board
#add reloaded guns, try to reduce respawn time
#Improve leaderboard
#Add scenary
#Make sure the functions all work for both players in the map

InstantRespawn := class(creative_device):
 
    respawnposition: vector3=vector3{X:= 250.00, Y:= 0.01, Z:= 161.9}
 
    @editable
    ElimMachine : elimination_manager_device = elimination_manager_device{}
    @editable
    TeleporterTeam1 : teleporter_device = teleporter_device{}
    @editable
    TeleporterTeam2 : teleporter_device = teleporter_device{}
 
    NowRespawn(Agent: agent)<suspends>:void=
        Sleep(0.1)
        Agent.Respawn(respawnposition, rotation{})
        TeleporterTeam1 .Teleport(Agent)
        TeleporterTeam2 .Teleport(Agent)
 
    SelfEliminated(Agent:agent):void=
        spawn{NowRespawn(Agent)}
 
    OnBegin<override>()<suspends>:void=
        ElimMachine.EliminatedEvent.Subscribe(SelfEliminated)

PlayerStats := class<unique>():
    var TotalElims : int = 0
    var TotalDeaths : int = 0

    AddElims(num:int): void=
        set TotalElims += num

    AddDeath(num:int): void=
        set TotalDeaths += num

    GetElimCount():int=
        return TotalElims

    GetDeathCount():int=
        return TotalDeaths

countdown_timer := class:
    block:
        set Canvas = canvas:
            Slots := array:
                canvas_slot:
                    Anchors := anchors:
                        Minimum := vector2{X := 0.5, Y := 0.05}
                        Maximum := vector2{X := 0.5, Y := 0.05}
                    Alignment := vector2{X := 0.5, Y := 0.0}
                    Offsets := margin{Top := 0.0, Left := 0.0, Bottom := 300.0, Right := 300.0}
                    SizeToContent := false
                    Widget := RemainingTimeWidget 
                    
    MaybePlayerUI : ?player_ui = false
    var RemainingTime : float = 0.0
    var Canvas : canvas = canvas{}
    RemainingTimeWidget : text_block = text_block{DefaultTextColor := NamedColors.White}
    RemainingTimeText<localizes>(CurrentRemainingTime : int) : message = "{CurrentRemainingTime}"
    TimerTickPeriod : float = 1.0 # The timer "precision": how often, in seconds, it ticks.

    RunCountdown()<suspends> : void =
        loop:
            Sleep(TimerTickPeriod) # Wait TimerTickPeriod seconds before updating the UI again.
            set RemainingTime -= TimerTickPeriod # Update how much time is left in the countdown after waiting
  
            UpdateUI()
  
            # Timer End
            if (RemainingTime <= 0.0):
                if (PlayerUI := MaybePlayerUI?):
                    PlayerUI.RemoveWidget(Canvas)
                break

    StartCountdown() : void =
        Print("Starting countdown")
    
        if (PlayerUI := MaybePlayerUI?):
            PlayerUI.AddWidget(Canvas)
    
            # Update the UI when we start the timer to see the initial RemainingTime on screen
            UpdateUI()
    
            spawn:
                RunCountdown()
    
    UpdateUI() : void =
        if (IntTime := Int[RemainingTime]):
            RemainingTimeWidget.SetText(RemainingTimeText(IntTime))

# A Verse-authored creative device that can be placed in a level
hello_world_device := class(creative_device):

    @editable
    StartButton:button_device = button_device{}

    @editable
    StartWall1:creative_prop = creative_prop{}

    @editable
    UnderMapZone:mutator_zone_device = mutator_zone_device{}

    @editable
    OverMapZone:mutator_zone_device = mutator_zone_device{}

    @editable
    RampTeleporter1:teleporter_device = teleporter_device{}

    @editable
    RampTeleporter2:teleporter_device = teleporter_device{}

    @editable
    BuildBreaker:explosive_device = explosive_device{}

    @editable
    ResetButton:button_device = button_device{}

    @editable
    PlayerSpawner1:player_spawner_device = player_spawner_device{}

    @editable
    ResetTrigger:trigger_device = trigger_device{}

    @editable
    PlayerSpawner2:player_spawner_device = player_spawner_device{}

    @editable
    StatsLeaderBoard1:billboard_device = billboard_device{}

    @editable
    StatsLeaderBoard2:billboard_device = billboard_device{}

    @editable
    PlayerNameBoard1:billboard_device = billboard_device{}

    @editable
    PlayerNameBoard2:billboard_device = billboard_device{}

    @editable
    ItemReloader:item_granter_device = item_granter_device{}

    @editable
    EndGameDevice:end_game_device = end_game_device{}

    PlayerName1<localizes>(Agent:agent):message = "{Agent}"
    PlayerName2<localizes>(Agent:agent):message = "{Agent}"

    KillCountTextPlayer1<localizes>(count:int): message = "Eliminations: {count}"
    KillCountTextPlayer2<localizes>(count:int): message = "Eliminations: {count}"

    var CountDownClock:countdown_timer = countdown_timer{}

    var SelectMatchPointButtons:GUIbuttons = GUIbuttons{}

    var RiftNumberSelect: int = 0

    var PlayerMap : [player]PlayerStats = map{}

    # Runs when the device is started in a running game
    OnBegin<override>()<suspends>:void=
        StartButton.InteractedWithEvent.Subscribe(StartButtonPress)
        UnderMapZone.AgentEntersEvent.Subscribe(HandlePlayerOutOfBounds)
        OverMapZone.AgentEntersEvent.Subscribe(HandlePlayerOutOfBounds)
        ResetButton.InteractedWithEvent.Subscribe(ResetAllBuilds)
        PlayerSpawner1.SpawnedEvent.Subscribe(OnPlayerAdded)
        PlayerSpawner2.SpawnedEvent.Subscribe(OnPlayerAdded)
        GetPlayspace().PlayerRemovedEvent().Subscribe(OnPlayerRemoved)
        ResetTrigger.TriggeredEvent.Subscribe(ResetFromTrigger)
        UpdatePlayersInGame()


    OnPlayerAdded(NewPlayer:agent): void=
        if(PlayerObj :=player[NewPlayer]):
            if(PlayerExists := PlayerMap[NewPlayer]):
                #Player already in map nothing todo
            else:
                if(set PlayerMap[PlayerObj] = PlayerStats{}):
                    if(AgentStats := PlayerMap[PlayerObj]):
                        Print("My elims: {AgentStats.GetElimCount()}")
                    if(FortChar:fort_character := NewPlayer.GetFortCharacter[]):
                        UpdatePlayersInGame()
                        FortChar.EliminatedEvent().Subscribe(OnEliminated)

    OnEliminated(Result:elimination_result): void=
        RestartFight()
        Eliminator := Result.EliminatingCharacter
        Eliminated := Result.EliminatedCharacter
        
        if (FortCharacter := Eliminator?, EliminatorAgent := FortCharacter.GetAgent[]):
            AddElimination(EliminatorAgent)

        if (FortCharacter := Eliminated, EliminatedAgent := FortCharacter.GetAgent[]):
            AddDeath(EliminatedAgent)

    AddElimination(Agent:agent): void=
        if(PlayerObj := player[Agent]):
            if(AgentStats := PlayerMap[PlayerObj]):
                AgentStats.AddElims(1)
                EndGameEventAchieved(AgentStats,Agent)
                
                
    AddDeath(Agent:agent): void=
        if(PlayerObj := player[Agent]):
            if(AgentStats := PlayerMap[PlayerObj]):
                AgentStats.AddDeath(1)
                Print("{AgentStats.GetDeathCount()}")

    OnPlayerRemoved(OutPlayer:player): void=
        if(ActualPlayer := PlayerMap[OutPlayer]):
            var TempPlayerMap:[player]PlayerStats = map{}
            #Creates a new map
            for(Key -> Value: PlayerMap, Key <> OutPlayer):
                set TempPlayerMap = ConcatenateMaps(TempPlayerMap, map{Key => Value})
                #Adds all values in old map into the new map
            set PlayerMap = TempPlayerMap
            #Sets old map to new map and the temp map is lost after the function

    StartButtonPress(Agent:agent): void=
        spawn:
            StartFight(Agent)
        UpdatePlayersInGame()
        
    StartFight(Agent:agent)<suspends> : void=
        StartButton.Disable()
        StartCountdown()
        Sleep(2.0)
        BarrierDisappear()
        Sleep(3.0)
        BarrierShow()
        StartButton.Enable()

    HandlePlayerOutOfBounds(Agent:agent): void=
        RestartFight()

    RestartFight(): void=
        AllPlayers := GetPlayspace().GetPlayers()
        for (Agent : AllPlayers):
            ItemReloader.GrantItem(Agent)
            TeleportToStartRamp(Agent)
            

    StartCountdown() : void=
        AllPlayers := GetPlayspace().GetPlayers()
        for (Agent : AllPlayers):
            if:
                FirstPlayer := Agent
                PlayerUI := GetPlayerUI[player[FirstPlayer]]
            then:
                set CountDownClock = countdown_timer{MaybePlayerUI := option{PlayerUI}, RemainingTime := 2.0}
                CountDownClock.StartCountdown()
            else:
                Print("Can't find player")

    BarrierDisappear(): void=
        StartWall1.Hide()

    BarrierShow(): void=
        StartWall1.Show()

    TeleportToStartRamp(Agent:agent): void=
        if:
            RiftNumberSelect = 0
        then:
            RampTeleporter1.Teleport(Agent)
            set RiftNumberSelect = 1
        else:
            RampTeleporter2.Teleport(Agent)
            set RiftNumberSelect = 0
        ResetAllBuilds(Agent)
        UpdatePlayersInGame()

    ResetFromTrigger(Activator:?agent): void=
        if(PlayerAgent:= Activator?):
            Agent := PlayerAgent
            HandlePlayerOutOfBounds(Agent)
       
    ResetAllBuilds(Agent:agent): void=
        BuildBreaker.Explode(Agent)
        BuildBreaker.Reset()

    UpdatePlayersInGame(): void=
        AllPlayers := GetPlayspace().GetPlayers()
        var PlayerNum: int = 0
        for (Agent : AllPlayers):
            if(PlayerNum = 0):
                UpdatePlayerNameBillboard1(Agent)
                if(PlayerObj := player[Agent]):
                    if(AgentStats := PlayerMap[PlayerObj]):
                        StatsLeaderBoard1.SetText(KillCountTextPlayer1(AgentStats.GetElimCount()))
            if(PlayerNum = 1):
                UpdatePlayerNameBillboard2(Agent)
                if(PlayerObj := player[Agent]):
                    if(AgentStats := PlayerMap[PlayerObj]):
                        StatsLeaderBoard2.SetText(KillCountTextPlayer2(AgentStats.GetElimCount()))
            set PlayerNum  += 1
            
    UpdateStatsBillboards(Agent: agent): void =
        if(PlayerObj := player[Agent]):
            if(AgentStats := PlayerMap[PlayerObj]):
                AgentStats.GetElimCount()

    UpdatePlayerNameBillboard1(Agent:agent): void=
        PlayerNameBoard1.SetText(PlayerName1(Agent))
        
    UpdatePlayerNameBillboard2(Agent:agent): void=
        PlayerNameBoard2.SetText(PlayerName1(Agent))

    EndGameEventAchieved(EliminatorStats:PlayerStats,Agent:agent): void=
        Eliminations:int = EliminatorStats.GetElimCount()
        Deaths:int = EliminatorStats.GetDeathCount()
        Difference: int = Eliminations - Deaths
        if:
            SelectMatchPointButtons.WinByTwo = true
            Eliminations >= SelectMatchPointButtons.EliminationsToWin
            Difference >= 2
        then:
            EndGameDevice.Activate(Agent)
        

GUIbuttons:= class(creative_device):

    @editable
    FirstToBoard:billboard_device = billboard_device{}

    @editable
    WinByBoard:billboard_device = billboard_device{}

    @editable
    var MyButton : button_device = button_device{}
    
    var EliminationsToWin: int = 5
    var WinByTwo: logic = true
    
    var MaybeMyUIPerPlayer : [player]?canvas = map{}
    
    OnBegin<override>()<suspends>:void=
        MyButton.InteractedWithEvent.Subscribe(AssignAllHUDS)
    
    AssignAllHUDS(Agent:agent):void=
        Print("Assigning all huds")
        CurrentPlayers := GetPlayspace().GetPlayers()
        for(Player:CurrentPlayers):
            if(MyAgent := agent[Player]):
                CreateHUDForAgents(MyAgent)
    
    CreateHUDForAgents(Agent:agent):void=
        Print("MyButton was pressed")
        if(Player:=player[Agent], PlayerUI:=GetPlayerUI[Player]):
            #If the player has a canvas:
            if(MyUI:=MaybeMyUIPerPlayer[Player]?):
                Print("Player already has a HUD")
                PlayerUI.RemoveWidget(MyUI)
                if(set MaybeMyUIPerPlayer[Player] = false){}
            #If the player does not have a canvas:
            else:
                Print("Player does not have a HUD")
                var MyCanvas : canvas = MakeCanvas()
                PlayerUI.AddWidget(MyCanvas,player_ui_slot{InputMode:=ui_input_mode.All})
                if(set MaybeMyUIPerPlayer[Player] = option{MyCanvas}){}

    Button1_Text : string = "First to 3"
    Button1_Position : vector2 = vector2{X := 250.0, Y := 400.0}
    Button1_Size : vector2 = vector2{X := 400.0, Y := 150.0}
    
    Button2_Text : string = "First to 5"
    Button2_Position : vector2 = vector2{X := 750.0, Y := 400.0}
    Button2_Size : vector2 = vector2{X := 400.0, Y := 150.0}
    
    Button3_Text : string = "First to 10"
    Button3_Position : vector2 = vector2{X := 1250.0, Y := 400.0}
    Button3_Size : vector2 = vector2{X := 400.0, Y := 150.0}
    
    Button4_Text : string = "Win by two on"
    Button4_Position : vector2 = vector2{X := 500.0, Y := 600.0}
    Button4_Size : vector2 = vector2{X := 400.0, Y := 150.0}
    
    Button5_Text : string = "Win by two off"
    Button5_Position : vector2 = vector2{X := 1000.0, Y := 600.0}
    Button5_Size : vector2 = vector2{X := 400.0, Y := 150.0}

    Button6_Text : string = "Exit"
    Button6_Position : vector2 = vector2{X := 1300.0, Y := 700.0}
    Button6_Size : vector2 = vector2{X := 400.0, Y := 150.0}
    
    StringToMessage<localizes>(S:string):message="{S}"
    
    MakeCanvas():canvas=
    
        ButtonFT3 : button_loud = button_loud{}
        ButtonFT3.SetText(StringToMessage(Button1_Text))
        ButtonFT3.OnClick().Subscribe(HandleButtonFT3)
    
        ButtonFT5 : button_loud = button_loud{}
        ButtonFT5.SetText(StringToMessage(Button2_Text))
        ButtonFT5.OnClick().Subscribe(HandleButtonFT5)
    
        ButtonFT10 : button_loud = button_loud{}
        ButtonFT10.SetText(StringToMessage(Button3_Text))
        ButtonFT10.OnClick().Subscribe(HandleButtonFT10)

        ButtonWB2T : button_loud = button_loud{}
        ButtonWB2T.SetText(StringToMessage(Button4_Text))
        ButtonWB2T.OnClick().Subscribe(HandleButtonWB2T)

        ButtonWB2F : button_loud = button_loud{}
        ButtonWB2F.SetText(StringToMessage(Button5_Text))
        ButtonWB2F.OnClick().Subscribe(HandleButtonWB2F)

        ButtonExit : button_loud = button_loud{}
        ButtonExit.SetText(StringToMessage(Button6_Text))
        ButtonExit.OnClick().Subscribe(HandleButtonExit)

        var MyCanvas : canvas = canvas:
            #add contents of canvas
            Slots := array:
                canvas_slot:
                    Widget:=ButtonFT3
                    ZOrder:=0
                    SizeToContent:=true
                    Offsets:=margin{Top:=Button1_Position.Y,Left:=Button1_Position.X,Bottom:=Button1_Size.Y,Right:=Button1_Size.X}
    
                canvas_slot:
                    Widget:=ButtonFT5
                    ZOrder:=1
                    SizeToContent:=true
                    Offsets:=margin{Top:=Button2_Position.Y,Left:=Button2_Position.X,Bottom:=Button2_Size.Y,Right:=Button2_Size.X}

                canvas_slot:
                    Widget:=ButtonFT10
                    ZOrder:=1
                    SizeToContent:=true
                    Offsets:=margin{Top:=Button3_Position.Y,Left:=Button3_Position.X,Bottom:=Button3_Size.Y,Right:=Button3_Size.X}

                canvas_slot:
                    Widget:=ButtonWB2T
                    ZOrder:=1
                    SizeToContent:=true
                    Offsets:=margin{Top:=Button4_Position.Y,Left:=Button4_Position.X,Bottom:=Button4_Size.Y,Right:=Button4_Size.X}

                canvas_slot:
                    Widget:=ButtonWB2F
                    ZOrder:=1
                    SizeToContent:=true
                    Offsets:=margin{Top:=Button5_Position.Y,Left:=Button5_Position.X,Bottom:=Button5_Size.Y,Right:=Button5_Size.X}

            
                canvas_slot:
                    Widget:=ButtonExit
                    ZOrder:=1
                    SizeToContent:=true
                    Offsets:=margin{Top:=Button6_Position.Y,Left:=Button6_Position.X,Bottom:=Button6_Size.Y,Right:=Button6_Size.X}
    
        return MyCanvas
    
    HandleButtonFT3(Wdata:widget_message):void=
        set EliminationsToWin = 3
        FirstToBoard.SetText(StringToMessage("First to 3"))
    
    HandleButtonFT5(Wdata:widget_message):void=
        set EliminationsToWin = 5
        FirstToBoard.SetText(StringToMessage("First to 5"))

    HandleButtonFT10(Wdata:widget_message):void=
        set EliminationsToWin = 10
        FirstToBoard.SetText(StringToMessage("First to 10"))

    HandleButtonWB2T(Wdata:widget_message):void=
        set WinByTwo = true
        WinByBoard.ShowText()

    HandleButtonWB2F(Wdata:widget_message):void=
        set WinByTwo = false
        WinByBoard.HideText()

    HandleButtonExit(Wdata:widget_message):void=
        RemoveHUD(Wdata)
    
    RemoveAllHUDS(Agent:?agent):void=
        Print("Removing All HUDS")
        CurrentPlayers := GetPlayspace().GetPlayers()
        for(Player:CurrentPlayers):
            if(MyAgent:=agent[Player]):
                if(PlayerUI:=GetPlayerUI[Player], MyUI:=MaybeMyUIPerPlayer[Player]?):
                    PlayerUI.RemoveWidget(MyUI)
                    if(set MaybeMyUIPerPlayer[Player] = false){}
    
    RemoveHUD(Wdata:widget_message):void=
        Print("Removing HUD")
        if(Player:=Wdata.Player, PlayerUI:=GetPlayerUI[Player], SelectedButton:=Wdata.Source):
            if(MyUI:=MaybeMyUIPerPlayer[Player]?):
                PlayerUI.RemoveWidget(MyUI)
                if(set MaybeMyUIPerPlayer[Player] = false){}