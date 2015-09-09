#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define TEAM_RADIANT			2
#define TEAM_DIRE				3

#define MODE_ALL_PICK			1
#define MODE_CAPTAINS_MODE		2
#define MODE_RANDOM_DRAFT		3
#define MODE_SINGLE_DRAFT		4
#define MODE_ALL_RANDOM			5
#define MODE_HEROES_BEGINNERS	6
#define MODE_DIRETIDE			7
#define MODE_REVERSE_CP			8
#define MODE_THE_GREEVILING		9
#define MODE_TUTORIAL			10
#define MODE_MID_ONLY			11
#define MODE_LEAST_PLAYED		12
#define MODE_NEW_PLAYER_POOL	13

#define STATE_INIT				0
#define STATE_PLAYERS_LOAD		1
#define STATE_HERO_SELECTION	2
#define STATE_STRATEGY_TIME		3
#define STATE_PRE_GAME			4
#define STATE_GAME_IN_PROGRESS	5
#define STATE_POST_GAME			6
#define STATE_DISCONNECT		7

new towersKilledRadiant, towersKilledDire;
new playersKilledRadiant, playersKilledDire;
new matchID, gameMode, gameState, String:gameHero[64], bool:matchDone;
new String:usersTeams[4][32][32], playersCount;
new String:addressSourceTV[64];
new Handle:setMatchID, Handle:setHero, Handle:setMaxTowers, Handle:setMaxKills, Handle:setRunes, Handle:setNeutrals;
new Handle:timerMatchAbort = INVALID_HANDLE, Handle:timerPlayerDisconnect = INVALID_HANDLE;
new bool:paused, bool:serverIsFull;

public Plugin:myinfo = {
	name = "CB.DOTA2",
	author = "Maxpain",
	description = "dota2comeback.com matchmaking plugin",
	version = "1.0.0",
	url = "http://dota2comeback.com/"
};

public OnPluginStart() {
	HookEvent("dota_match_done", Event_MatchDone);
	HookEvent("entity_killed", Event_EntityKilled);
	HookEvent("game_rules_state_change", Event_GameStateChange);

	AddCommandListener(Listener_SelectHero, "dota_select_hero");

	setMatchID = CreateConVar("set_match_id", "0", "Set current match ID", FCVAR_PLUGIN, false, 0.0, false, 0.0);
	setHero = CreateConVar("set_hero", "0", "Set hero classname for 1x1 mid only matches", FCVAR_PLUGIN, false, 0.0, false, 0.0);
	setMaxTowers = CreateConVar("set_max_towers", "0", "Set max towers for 1x1-3x3 games", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	setMaxKills = CreateConVar("set_max_kills", "0", "Set max kills for 1x1-3x3 games", FCVAR_PLUGIN, true, 0.0, true, 5.0);
	setRunes = CreateConVar("set_runes", "1", "Set spwaning runes", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	setNeutrals = CreateConVar("set_neutrals", "1", "Set spawning neutrals", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	timerMatchAbort = CreateTimer(180.0, MatchAbort);
}

public OnGameFrame() {
	if (gameState == STATE_GAME_IN_PROGRESS) {
		serverIsFull = GetRealClientCount() == playersCount;
	}

	if (paused && !serverIsFull) {
		if (!GameRules_GetProp("m_bGamePaused")) {
			GameRules_SetProp("m_bGamePaused", 1);
		}
	}
}

public Action:UnPause(Handle:timer) {
	paused = false;
	ServerCommand("say \"3 минуты прошло, вы можете снять паузу\"");
}

public Action:MatchAbort(Handle:timer) {
	LogToGame("MATCH_ABORT, MATCH_ID: %d", matchID);
	ServerCommand("exit");
}

public OnConfigsExecuted() {
	GetConVarString(setHero, gameHero, sizeof(gameHero));

	gameMode = GetConVarInt(FindConVar("dota_force_gamemode"));
	playersCount = GetConVarInt(FindConVar("dota_wait_for_players_to_load_count"));

	SetMatchData();
	SetAddressSourceTV();
	SetNeutrals();
}

public SetNeutrals() {
	if (!GetConVarBool(setNeutrals)) {
		new Handle:setNeutralsDelay = FindConVar("dota_neutral_initial_spawn_delay");
		SetConVarString(setNeutralsDelay, "5000", true);

		new Handle:setNeutralsInterval = FindConVar("dota_neutral_spawn_interval");
		SetConVarString(setNeutralsInterval, "5000", true);
	}
}

public OnClientAuthorized(client, const String:auth[]) {
	if (IsClientSourceTV(client)) return;

	if (!GetPlayerTeam(auth) || IsFakeClient(client)) {
		if (GetConVarBool(FindConVar("tv_enable"))) {
			ClientCommand(client, "connect_hltv %s", addressSourceTV);
		} else {
			ServerCommand("kickid %d", GetClientUserId(client));
		}
	}
}

public OnClientDisconnect(client) {
	new String:auth[64];

	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	new team = GetPlayerTeam(auth);

	if (gameState == STATE_GAME_IN_PROGRESS && team) {
		if (GetRealClientCount() == 0) {
			CreateTimer(180.0, MatchAbort);
		} else {
			paused = true;

			if (timerPlayerDisconnect == INVALID_HANDLE) {
				timerPlayerDisconnect = CreateTimer(180.0, UnPause);
			}

			new String:username[64];
			GetClientName(client, username, sizeof(username));

			ServerCommand("say \"Пользователь %s покинул игру, установлена пауза на 3 минуты\"", username);
		}
	}
}

public GetPlayerTeam(const String:steamID[]) {
	for (new i = 0; i < playersCount; i++) {
		if (StrEqual(steamID, usersTeams[2][i])) return 2;
		else if (StrEqual(steamID, usersTeams[3][i])) return 3;
	}

	return false;
}

public OnClientPutInServer(client) {
	if (IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client)) return;

	decl String:auth[32];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));

	decl String:auth3[32];
	GetClientAuthId(client, AuthId_Steam3, auth3, sizeof(auth3));

	new team = GetPlayerTeam(auth);

	if (team == 2) {
		FakeClientCommand(client, "jointeam good");
	} else if (team == 3) {
		FakeClientCommand(client, "jointeam bad");
	}

	if (gameMode == MODE_MID_ONLY && playersCount == 2 && strlen(gameHero) > 1) {
		FakeClientCommand(client, "dota_select_hero %s reserve", gameHero);
	}

	if (gameState == STATE_PLAYERS_LOAD) {
		if (timerMatchAbort != INVALID_HANDLE) {
			KillTimer(timerMatchAbort);
			timerMatchAbort = INVALID_HANDLE;
		}
	} else if (gameState == STATE_GAME_IN_PROGRESS) {
		if (GetRealClientCount() == playersCount) {
			if (timerMatchAbort != INVALID_HANDLE) {
				KillTimer(timerMatchAbort);
				KillTimer(timerPlayerDisconnect);
				timerMatchAbort = INVALID_HANDLE;
				timerPlayerDisconnect = INVALID_HANDLE;
			}

			
			paused = false;
			ServerCommand("say \"Вы можете снять паузу\"");
		}
	}
}

public SetMatchData() {
	matchID = GetConVarInt(setMatchID);
	decl String:fileName[64], String:line[64];

	Format(fileName, sizeof(fileName), "matches/%d.ini", matchID);

	if (FileExists(fileName)) {
		new Handle:file = OpenFile(fileName, "r");

		new i = 0;

		while (!IsEndOfFile(file) && ReadFileLine(file, line, sizeof(line))) {
			new String:steamID[32], String:sTeam[5];

			new len = BreakString(line, steamID, sizeof(steamID));

			ReplaceString(steamID, sizeof(steamID), "STEAM_0", "STEAM_1");

			BreakString(line[len], sTeam, sizeof(sTeam));
			new team = StringToInt(sTeam);
			usersTeams[team][i] = steamID;

			i++;
		}

		CloseHandle(file);
		DeleteFile(fileName);
	}

}

public SetAddressSourceTV() {
	decl String:ip[32];
	GetConVarString(FindConVar("ip"), ip, sizeof(ip));

	Format(addressSourceTV, sizeof(addressSourceTV), "%s:%d", ip, GetConVarInt(FindConVar("tv_port")));
}


public Action:RemoveRunes(Handle:timer) {
	new ent = -1;
	new prev = 0;

	new Float:origin[] = {-999999999999.0, -999999999999.0, -999999999999.0};

	while ((ent = FindEntityByClassname(ent, "dota_item_rune")) != -1) {
		if (prev) TeleportEntity(prev, origin, NULL_VECTOR, NULL_VECTOR);
		prev = ent;
	}

	if (prev) TeleportEntity(prev, origin, NULL_VECTOR, NULL_VECTOR);
}

public Action:Listener_SelectHero(client, const String:command[], argc) {
	if (gameMode == MODE_MID_ONLY && playersCount == 2) {
		decl String:arg[64];
		GetCmdArg(1, arg, sizeof(arg));

		if (StrEqual(arg, "repick")) {
			if (strlen(gameHero) > 1) {
				return Plugin_Handled;
			}
		} else if (StrEqual(arg, "npc_dota_hero_broodmother")
				|| StrEqual(arg, "npc_dota_hero_npc_dota_hero_broodmother")
				|| StrEqual(arg, "npc_dota_hero_jakiro")
				|| StrEqual(arg, "npc_dota_hero_npc_dota_hero_jakiro")
				|| StrEqual(arg, "npc_dota_hero_venomancer")
				|| StrEqual(arg, "npc_dota_hero_npc_dota_hero_venomancer")) {
			if (strlen(gameHero) == 1) {
				PrintToChat(client, "Запрещено пикать героев Broodmother, Jakiro и Venomancer");
				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

public Action:Event_GameStateChange(Handle:event, const String:name[], bool:dontBroadcast) {
	gameState = GameRules_GetProp("m_nGameState");

	switch (gameState) {
		case STATE_HERO_SELECTION: {
			if (GetRealClientCount() < playersCount) {
				LogToGame("MATCH_ABORT, MATCH_ID: %d", GetConVarInt(setMatchID));
				ServerCommand("exit");
			}

			if (gameMode == MODE_MID_ONLY && playersCount == 2 && strlen(gameHero) > 1) {
				for (new client = 1; client <= MaxClients; client++) {
					if (IsClientConnected(client) && !IsFakeClient(client) && !IsClientSourceTV(client) && !IsClientReplay(client)) {
						FakeClientCommand(client, "dota_select_hero %s reserve", gameHero);
					}
				}
			}
		}

		case STATE_GAME_IN_PROGRESS: {
			if (!GetConVarBool(setRunes)) {
				CreateTimer(120.0, RemoveRunes, INVALID_HANDLE, TIMER_REPEAT);
				CreateTimer(0.1, RemoveRunes, INVALID_HANDLE, TIMER_REPEAT);
			}

			if (GetRealClientCount() < playersCount) {
				MatchAbort(INVALID_HANDLE);
			}
		}

		case STATE_DISCONNECT: {
			if (!matchDone) {
				LogToGame("MATCH_ABORT, MATCH_ID: %d", GetConVarInt(setMatchID));
			}

			ServerCommand("exit");
		}
	}

	LogToGame("GAME_STATE: %d, MATCH_ID: %d", gameState, GetConVarInt(setMatchID));
}

public Action:Event_MatchDone(Handle:event, const String:name[], bool:dontBroadcast) {
	matchDone = true;
	LogToGame("MATCH_END: %d, MATCH_ID: %d", GetEventInt(event, "winningteam"), GetConVarInt(setMatchID));
}

public Action:Event_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast) {
	decl String:entityName[50];

	new entity = GetEventInt(event, "entindex_killed");
	GetEntityClassname(entity, entityName, sizeof(entityName));

	if (StrEqual(entityName, "npc_dota_tower")) {
		if (GetConVarInt(setMaxTowers) > 0) {
			new team = GetEntProp(entity, Prop_Data, "m_iTeamNum", 4);

			if (team == TEAM_RADIANT) {
				towersKilledRadiant++;
				if (towersKilledRadiant >= GetConVarInt(setMaxTowers)) {
					ServerCommand("sv_cheats 1; dota_dev bad_guys_win");
				}
			} else {
				towersKilledDire++;
				if (towersKilledDire >= GetConVarInt(setMaxTowers)) {
					ServerCommand("sv_cheats 1; dota_dev good_guys_win");
				}
			}
		}
	} else if (StrContains(entityName, "npc_dota_hero", true) != -1) {
		if (GetConVarInt(setMaxKills) > 0) {
			new team = GetEntProp(entity, Prop_Data, "m_iTeamNum", 4);
			new attacker = GetEventInt(event, "entindex_attacker");
			new inflictor = GetEventInt(event, "entindex_inflictor");
			new victim = GetEventInt(event, "entindex_killed");

			LogToGame("ENTITY_KILLED: %d, %d, %d, MATCH_ID: %d", attacker, inflictor, victim, GetConVarInt(setMatchID));

			if (attacker != victim) {
				if (team == TEAM_RADIANT) {
					playersKilledRadiant++;
					if (playersKilledRadiant >= GetConVarInt(setMaxKills)) {
						ServerCommand("sv_cheats 1; dota_dev bad_guys_win; sv_cheats 0");
					}
				} else {
					playersKilledDire++;
					if (playersKilledDire >= GetConVarInt(setMaxKills)) {
						ServerCommand("sv_cheats 1; dota_dev good_guys_win; sv_cheats 0");
					}
				}
			}
		}
	}
}

stock GetRealClientCount(bool:inGameOnly = true) {
	new clients = 0;

	for(new i = 1; i <= GetMaxClients(); i++) {
		if(((inGameOnly) ? IsClientInGame(i) : IsClientConnected(i)) && !IsFakeClient(i)) {
			clients++;
		}
	}

	return clients;
}