extends Node3D
# Player scene reference (set this in the inspector)
@export var player_scene: PackedScene
@export var bomb_scene: PackedScene
@export var explosion_scene: PackedScene

@onready var time_label: Label = $CanvasLayer/TIME_LABEL
@onready var timer: Timer = $Timer

# Player container node
@onready var players_node: Node3D = $Players
@onready var player_spawn_points: Node3D = $PlayerSpawnPoints
var spawn_points := []
# Dictionary to track spawned players by peer ID

var spawned_players := {}
@export var alive_players := []
var eliminated_players := []

@onready var bombs: Node3D = $Bombs
@onready var dead_zone: StaticBody3D = $DEAD_ZONE

var bomb = null
var is_game_finished = false

signal start_game()

func _ready():
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(self._mp_peer_connected)
	multiplayer.peer_disconnected.connect(self._mp_peer_disconnected)
	_spawn_bomb()
	_create_spawn_points()
	
	# Spawn the local player immediately if we're in a multiplayer session
	if multiplayer.has_multiplayer_peer():
		_spawn_player(multiplayer.get_unique_id())
	
	for i in multiplayer.get_peers():
		_spawn_player(i)


func _create_spawn_points():
	spawn_points.clear()
	for j in player_spawn_points.get_children():
		spawn_points.append(j.global_position)

func _mp_peer_connected(id: int):
	_spawn_player(id)
	
func _mp_peer_disconnected(id: int):
	_despawn_player(id)

func _spawn_player(id: int):
	# Don't spawn if already exists
	if spawned_players.has(id):
		return
		
	# Instantiate new player
	var new_player = player_scene.instantiate()
	players_node.add_child(new_player)
	# Configure player
	new_player.name = str(id)
	new_player.set_multiplayer_authority(id)
	# Set as local player if this is our ID
	if id == multiplayer.get_unique_id():
		new_player.change_color(GoData.MYcolor)
		new_player.is_local_player = true
	else:
		new_player.change_color(GoData.peers[id]["color"])
		new_player.is_local_player = false
	
	var random_number = randi_range(0,spawn_points.size() - 1)
	
	new_player.global_position = spawn_points[random_number]
	self.start_game.connect(new_player._game_started)
	if spawn_points.size() < 1:
		new_player.global_position = dead_zone.global_position
	else:
		alive_players.append(id)
		spawn_points.erase(random_number)
	# Store reference
	spawned_players[id] = new_player
	
	PrintHelper.debug("Spawned player for peer: %s" % id)


func _despawn_player(id: int):
	if not spawned_players.has(id):
		return
	
	var player = spawned_players[id]
	if is_instance_valid(player):
		player.queue_free()
	
	spawned_players.erase(id)
	alive_players.erase(id)
	PrintHelper.debug("Despawned player for peer: %s" % id)


func _physics_process(delta: float) -> void:
	if not is_game_finished:
		time_label.text = "Next bomber in : %s second." % int(timer.time_left)
	pass

func _on_timer_timeout() -> void:
	_select_bomber()
	start_game.emit()

func _select_bomber():
	if multiplayer.get_unique_id() == 1:
		if alive_players.size() > 1:
			var random_number = randi_range(0,alive_players.size() - 1)
			_bomb_owner.rpc(alive_players[random_number])
		else:
			_restart.rpc(alive_players)

@rpc("any_peer","call_local","reliable")
func _restart(who):
	is_game_finished = true
	time_label.text = "%s WON! - GAME WILL RESTART IN 5 SECOND." % GoData.peers[alive_players[0]["nickname"]]
	await get_tree().create_timer(5).timeout
	get_tree().change_scene_to_file("res://addons/go_p2p/template/3D/world_3d.tscn")


func _spawn_bomb():
	bomb = bomb_scene.instantiate()
	bombs.add_child(bomb)
	bomb.explode.connect(self._eliminate_player)
	bomb.change_player.connect(self._change_target)

func _eliminate_player(who,pos):
	if multiplayer.get_unique_id() == 1:
		var temp_who = int(who)
		_eliminate.rpc(temp_who,pos)


func _change_target(who):
	if multiplayer.get_unique_id() != 1:
		_change_hand.rpc(who)
		return

@rpc("any_peer","call_local","reliable")
func _change_hand(who):
	bomb.stick_owner(players_node.get_node(str(who)))

@rpc("any_peer","call_local","reliable")
func _eliminate(who,pos):
	var explosion = explosion_scene.instantiate()
	add_child(explosion)
	explosion.global_position = pos
	
	spawned_players[who]._eliminated(dead_zone.global_position)
	alive_players.erase(int(who))
	bomb.queue_free()
	_spawn_bomb()
	timer.start()


@rpc("any_peer","call_local","reliable")
func _bomb_owner(id):
	var placement = players_node.get_node(str(id))
	bomb.stick_owner(placement)
