//List of the classes exported to LUA

class callback {
	const trade_start					= 0;
	const trade_stop					= 1;
	const trade_sell_buy_item			= 2;
	const trade_perform_operation		= 3;

	const zone_enter					= 4;
	const zone_exit						= 5;
	const level_border_exit				= 6;
	const level_border_enter			= 7;
	const death							= 8;

	const patrol_path_in_point			= 9;
	const inventory_info				= 10;
	const article_info					= 11;
	const task_state					= 12;
	const map_location_added			= 13;

	const use_object					= 14;

	const hit							= 15;

	const sound							= 16;

	const action_movement				= 17;
	const action_watch					= 18;
	const action_animation				= 19;
	const action_sound					= 20;
	const action_particle				= 21;
	const action_object					= 22;

	const helicopter_on_point			= 23;
	const helicopter_on_hit				= 24;

	const on_item_take					= 25;
	const on_item_drop					= 26;

	const script_animation				= 27;

	const trader_global_anim_request	= 28;
	const trader_head_anim_request		= 29;
	const trader_sound_end				= 30;

	const take_item_from_box			= 31;
	const place_item_to_box				= 32;


	const on_key_press					= 33;
	const on_key_release				= 34;
	const on_key_hold					= 35;
	const on_mouse_wheel				= 36;
	const on_mouse_move					= 37;
	const on_belt						= 38;
	const on_ruck						= 39;
	const on_slot						= 40;
	const on_before_use_item			= 41;
	const entity_alive_before_hit		= 42;

	const update_addons_visibility		= 43;
	const update_hud_addons_visibility	= 44;
	const on_addon_init					= 45;
	const second_scope_switch			= 46;

	// These specifically say actor as I intend to add callbacks for NPCs firing their weapons.
	const on_actor_weapon_start_firing	= 47;
	const on_actor_weapon_fire			= 48;
	const on_actor_weapon_jammed		= 49;
	const on_actor_weapon_empty			= 50;
	const on_actor_weapon_reload		= 51;
	const on_actor_weapon_switch_gl		= 52;

	// NPC Weapon Callbacks.
	const on_npc_weapon_start_firing	= 53;
	const on_npc_weapon_fire			= 54;
	const on_npc_weapon_jammed			= 55;
	const on_npc_weapon_empty			= 56;
	const on_npc_weapon_reload			= 57;

	// Called when the player zooms their weapon in or out.
	const on_actor_weapon_zoom_in		= 58;
	const on_actor_weapon_zoom_out		= 59;

	const on_cell_item_focus			= 60;
	const on_cell_item_focus_lost		= 61;
	const on_cell_item_select			= 62;
	const on_cell_item_mouse			= 63;

	const on_before_save				= 64;
	const on_after_save					= 65;

	const on_level_map_click			= 66;
	const on_map_spot_click				= 67;

	const on_pickup_item_showing		= 68;
	const on_group_items				= 69;
	const on_weapon_shell_drop			= 70;
	const on_throw_grenade				= 71;
	const on_goodwill_change			= 72;
	const update_artefacts_on_belt		= 73;
	const level_changer_action			= 74;

	const on_attach_vehicle				= 75;
	const on_detach_vehicle				= 76;
	const on_use_vehicle				= 77;

	const on_inv_box_item_take			= 78;
	const on_inv_box_item_drop			= 79;
	const on_inv_box_open				= 80;

	const select_pda_contact			= 81;
};

class global_flags {
	// inventory_item
	const FdropManual					= 1;
	const FCanTake						= 2;
	const FCanTrade						= 4;
	const Fbelt							= 8;
	const Fruck							= 16;
	const FRuckDefault					= 32;
	const FUsingCondition				= 64;
	const FAllowSprint					= 128;
	const Fuseful_for_NPC				= 256;
	const FInInterpolation				= 512;
	const FInInterpolate				= 1024;
	const FIsQuestItem					= 2048;
	const FIAlwaysUntradable			= 4096;
	const FIUngroupable					= 8192;
	const FIHiddenForInventory			= 16384;
	// se_object_flags
	const flUseSwitches					= 1;
	const flSwitchOnline				= 2;
	const flSwitchOffline				= 4;
	const flInteractive					= 8;
	const flVisibleForAI				= 16;
	const flUsefulForAI					= 32;
	const flOfflineNoMove				= 64;
	const flUsedAI_Locations			= 128;
	const flGroupBehaviour				= 256;
	const flCanSave						= 512;
	const flVisibleForMap				= 1024;
	const flUseSmartTerrains			= 2048;
	const flCheckForSeparator			= 4096;
	// weapon_states
	const eIdle							= 0;
	const eFire							= 1;
	const eFire2						= 2;
	const eReload						= 3;
	const eShowing						= 4;
	const eHiding						= 5;
	const eHidden						= 6;
	const eMisfire						= 7;
	const eMagEmpty						= 8;
	const eSwitch						= 9;
	// RestrictionSpace
	const eDefaultRestrictorTypeNone	= 0;
	const eDefaultRestrictorTypeOut		= 1;
	const eDefaultRestrictorTypeIn		= 2;
	const eRestrictorTypeNone			= 3;
	const eRestrictorTypeIn				= 4;
	const eRestrictorTypeOut			= 5;
};

// do not exported
enum EItemPlace {
	eItemPlaceUndefined	= 0;
	eItemPlaceSlot		= 1;
	eItemPlaceBelt		= 2;
	eItemPlaceRuck		= 3;
	eItemPlaceBeltActor	= 4;
};

// do not exported
extern Flags32 psHUD_Flags {
	HUD_CROSSHAIR			= 1;
	HUD_CROSSHAIR_DIST		= 2;
	HUD_WEAPON				= 4;
	HUD_INFO				= 8;
	HUD_DRAW				= 16;
	HUD_CROSSHAIR_RT		= 32;
	HUD_WEAPON_RT			= 64;
	HUD_CROSSHAIR_DYNAMIC	= 128;
	HUD_CROSSHAIR_RT2		= 256;
	HUD_DRAW_RT				= 512;
	HUD_CROSSHAIR_BUILD		= 1024;
};

class alife_simulator {
	void use_ai_locations( CSE_ALifeDynamicObject*<object>, bool<use>);
	void assign_story_id( CSE_ALifeDynamicObject*<object>, int<story_id> );
};

class ini_file {
	property bool	readonly;

	void			remove_line( LPCSTR<section>, LPCSTR<line> );
	void			remove_section( LPCSTR<section> );
	void			w_bool( LPCSTR<section>, LPCSTR<line>, bool<value> );
	void			w_string( LPCSTR<section>, LPCSTR<line>, LPCSTR<value> );
	void			w_u32( LPCSTR<section>, LPCSTR<line>, u32<value> );
	void			w_s32( LPCSTR<section>, LPCSTR<line>, s32<value> );
	void			w_float( LPCSTR<section>, LPCSTR<line>, float<value> );
	void			w_vector( LPCSTR<section>, LPCSTR<line>, vector*<value> );
	string			get_as_string();
	void			iterate_sections( const luabind::functor<void>& functor(section) );
};

class cse_abstract : cpure_server_object {
	property vector*	position;
	property vector*	angle;
	property LPCSTR		custom_data;

	void				save_spawn_ini();
};

class game_object {
	CInventory*			inventory;
	CHitImmunity*		immunities;
	bool				is_alive;
	CEntityCondition*	conditions;
	u32					level_id;
	LPCSTR				level_name;

	CGameObject*				get_game_object();
	cse_alife_dynamic_object*	get_alife_object();
	CActor*						get_actor();
	CustomZone*					get_anomaly();
	CArtefact*					get_artefact();
	CBaseMonster*				get_base_monster();
	CInventoryContainer*		get_container();
	CCustomMonster*				get_custom_monster();
	CEatableItem*				get_eatable_item();
	CGrenade*					get_grenade();
	IInventoryBox*				get_inventory_box();
	CInventoryItem*				get_inventory_item();
	CInventoryOwner*			get_inventory_owner();
	CMissile*					get_missile();
	CCustomOutfit*				get_outfit();
	CSpaceRestrictor*			get_space_restrictor();
	CTorch*						get_torch();
	CWeapon*					get_weapon();
	CWeaponMagazined*			get_weapon_m();
	CWeaponMagazinedWGrenade*	get_weapon_mwg();
	CWeaponShotgun*				get_weapon_sg();
	CWeaponHUD*					get_weapon_hud();		// CWeapon
	IRenderVisual*				get_hud_visual();		// CWeapon
	void						load_hud_visual( LPCSTR<wpn_hud_section> );	// CWeapon

	void			ph_capture_object( game_object*<CPhysicsShellHolder> );							//CEntityAlive
	void			ph_capture_object( game_object*<CPhysicsShellHolder>, LPCSTR<capture_bone> );	//CEntityAlive
	void			ph_capture_object( game_object*<CPhysicsShellHolder>, u16<bone> );				//CEntityAlive
	void			ph_capture_object( game_object*<CPhysicsShellHolder>, u16<bone>, LPCSTR<capture_bone> );	//CEntityAlive
	void			ph_release_object();	//CEntityAlive
	CPHCapture*		ph_capture();			//CEntityAlive

	bool			throw_target( vector*<position>[, game_object*<throw_ignore_object>] );					// CAI_Stalker
	bool			throw_target( vector*<position>, u32<vertex_id>[, game_object*<throw_ignore_object>] );	// CAI_Stalker

	void			g_fireParams( game_object*<CHudItem>, vector*<fire_pos>, vector*<fire_dir> );	// CEntity
	float			stalker_disp_base();							// CAI_Stalker
	void			stalker_disp_base( float<disp> );				// CAI_Stalker
	void			stalker_disp_base( float<range>, float<maxr> );	// CAI_Stalker

	void			drop_item_and_throw( game_object*<CPhysicsShellHolder>, vector*<speed> );	// CInventoryOwner
	bool			controller_psy_hit_active();		// CController

	CCoverPoint*	best_cover(const Fvector &position, const Fvector &enemy_position, float radius, float min_enemy_distance, float max_enemy_distance, luabind::functor<bool> );											// CAI_Stalker
	CCoverPoint*	safe_cover( const Fvector &position, float radius, float min_distance, luabind::functor<bool>& callback );																								// CAI_Stalker
	CCoverPoint*	ambush_cover( const Fvector &position, const Fvector &enemy_position, float radius, float min_distance );																								// CAI_Stalker
	CCoverPoint*	ambush_cover( const Fvector &position, const Fvector &enemy_position, float radius, float min_distance, const luabind::functor<bool>& callback );														// CAI_Stalker
	CCoverPoint*	angle_cover( const Fvector &position, float radius, const Fvector &enemy_position, float min_enemy_distance, float max_enemy_distance, u32 enemy_vertex_id );											// CAI_Stalker
	CCoverPoint*	angle_cover( const Fvector &position, float radius, const Fvector &enemy_position, float min_enemy_distance, float max_enemy_distance, u32 enemy_vertex_id, const luabind::functor<bool>& callback );	// CAI_Stalker

	void			iterate_belt( const luabind::functor<void>& functor, const luabind::object& object );	// CInventoryOwner
	void			iterate_ruck( const luabind::functor<void>& functor, const luabind::object& object );	// CInventoryOwner

	float			get_actor_max_weight();										// CActor
	void			set_actor_max_weight( float<max_weight> );					// CActor
	float			get_actor_max_walk_weight();								// CActor
	void			set_actor_max_walk_weight( float<max_walk_weight> );		// CActor
	float			get_additional_max_weight();								// CCustomOutfit
	void			set_additional_max_weight( float<add_max_weight> );			// CCustomOutfit
	float			get_additional_max_walk_weight();							// CCustomOutfit
	void			set_additional_max_walk_weight( float<add_max_weight> );	// CCustomOutfit
	float			get_total_weight();											// CInventoryOwner
	float			weight();													// CInventoryItem

	bool			is_actor_outdoors();		// CActor

	game_object*	item_on_belt( u32<item_id> );	// CInventoryOwner
	game_object*	item_in_ruck( u32<item_id> );	// CInventoryOwner
	bool			is_on_belt( game_object*<CInventoryItem> );	// CInventoryOwner
	bool			is_in_ruck( game_object*<CInventoryItem> );	// CInventoryOwner
	bool			is_in_slot( game_object*<CInventoryItem> );	// CInventoryOwner
	void			move_to_ruck( game_object*<CInventoryItem> );	// CInventoryOwner
	void			move_to_belt( game_object*<CInventoryItem> );	// CInventoryOwner
	void			move_to_slot( game_object*<CInventoryItem> );	// CInventoryOwner
	u32				belt_count();		// CInventoryOwner
	u32				ruck_count();		// CInventoryOwner
	void			invalidate_inventory();	// CInventoryOwner

	void			set_inventory_item_flags( flags16*<flags> );	// CInventoryItem
	flags16*		get_inventory_item_flags();						// CInventoryItem

	bool			is_game_object();
	bool			is_car();
	bool			is_helicopter();
	bool			is_holder();
	bool			is_entity_alive();
	bool			is_inventory_item();
	bool			is_inventory_owner();
	bool			is_actor();
	bool			is_custom_monster();
	bool			is_weapon();
	bool			is_medkit();
	bool			is_eatable_item();
	bool			is_antirad();
	bool			is_outfit();
	bool			is_scope();
	bool			is_silencer();
	bool			is_grenade_launcher();
	bool			is_weapon_magazined();
	bool			is_weapon_shotgun();
	bool			is_space_restrictor();
	bool			is_stalker();
	bool			is_anomaly();
	bool			is_monster();
	bool			is_explosive();
	bool			is_script_zone();
	bool			is_projector();
	bool			is_lamp();
	bool			is_trader();
	bool			is_hud_item();
	bool			is_food_item();
	bool			is_artefact();
	bool			is_ammo();
	bool			is_physics_shell_holder();
	bool			is_grenade();
	bool			is_bottle_item();
	bool			is_torch();
	bool			is_weapon_gl();
	bool			is_inventory_box();
	bool			is_binoculars();
	bool			is_knife();

	void			set_camera_direction( vector*<direction> );	// CActor
	void			update_condition();				// CEntityAlive
	void			heal_wounds( float<delta> );	// CEntityAlive
	void			add_wounds( float<hit_power>, int<hit_type>, u16<element> );	// CEntityAlive
	float			get_weight();		// CInventoryItem
	u32				inv_box_count();	//IInventoryBox
	void			open_inventory_box( game_object*<IInventoryBox> );	// CInventoryOwner(CActor?)
	game_object*	object_from_inv_box( int<index> );		// IInventoryBox
	float			get_camera_fov();
	void			set_camera_fov( float<fov> );

	void			set_max_weight( float<weight> );		// CActor
	void			set_max_walk_weight( float<weight> );	// CActor
	float			get_max_weight();						// CInventoryOwner
	float			get_max_walk_weight();					// CActor
	float			get_inventory_weight();					// CInventoryOwner
	u32				calculate_item_price( game_object*<CInventoryItem>, bool<b_buying> );	// CInventoryOwner

	float			get_shape_radius();		// CSpaceRestrictor

	char			get_visual_name();
	ini_file*		get_visual_ini();		// IKinematics object visual

	void			set_bone_visible( LPCSTR<bone_name>, bool<visible> );		// IKinematics object visual
	void			set_hud_bone_visible( LPCSTR<bone_name>, bool<visible> );	// CHudItem
	bool			get_bone_visible( LPCSTR<bone_name> );		// IKinematics object visual
	bool			get_hud_bone_visible( LPCSTR<bone_name> );	// CHudItem
	u16				get_bone_id( LPCSTR<bone_name> );			// IKinematics object visual

	float			get_binoc_zoom_factor();						// CWeaponBinoculars
	void			set_binoc_zoom_factor( float<zoom> );	// CWeaponBinoculars
	float			get_zoom_factor();		// CWeapon
	u8<EWeaponAddonState>	get_addon_flags();		// CWeapon
	void			set_addon_flags( u8<flags EWeaponAddonState> );	// CWeapon
	u32				get_magazine_size();			// CWeapon
	void			set_magazine_size( int<size> );	// CWeapon
	bool			get_grenade_launcher_status();	// CWeapon
	u32				get_ammo_type();				// CWeapon
	u32				get_underbarrel_ammo_type();	// CWeaponMagazinedWGrenade
	u32				get_ammo_in_magazine2();		// CWeaponMagazinedWGrenade
	bool			get_gl_mode();					// CWeaponMagazinedWGrenade

	u32				get_current_ammo();						// CWeaponAmmo
	void			set_ammo_box_curr( u16<ammo_count> );	// CWeaponAmmo
	u16				get_ammo_box_size();					// CWeaponAmmo
	void			set_ammo_box_size( u16<box_size> );		// CWeaponAmmo

	void			set_hud_offset( vector*<offset> );		// CHudItem
	void			set_hud_rotate( vector2*<rotate> );		// CHudItem

	game_object*	get_holder();	// CActor
	CCameraBase*	get_camera();	// CCar

	bool			zoom_mode();	// CActor
	void			reset_state();	// CActor

	void			zero_effects();									// CEatableItem
	void			set_radiation_influence( float<radiation> );	// CEatableItem

	void			set_additional_radiation_protection( float<protection> );	// CActor
	void			set_additional_telepatic_protection( float<protection> );	// CActor

	CUIStatic*		get_cell_item();	// CInventoryItem
	LPCSTR			get_bone_name( u16<bone_id> );	// IKinematics object visual

	u32<global_flags*>	get_hud_item_state();	// CHudItem
	float			radius();	// CGameObject
	void			play_hud_animation( LPCSTR<anim> );					// CHudItem
	void			play_hud_animation( LPCSTR<anim>, bool<mix_in> );	// CHudItem

	void			add_feel_touch( float<radius>, const<luabind::object& lua_object>, const<luabind::functor<void>& new_delete> );		// CGameObject
	void			add_feel_touch( float<radius>, const<luabind::object& lua_object>, const<luabind::functor<void>& new_delete>, const<luabind::functor<bool>& contact> );	// CGameObject
	void			remove_feel_touch( const<luabind::object& lua_object>, const<luabind::functor<void>& new_delete> );	// CGameObject
	void			remove_feel_touch( const<luabind::object& lua_object>, const<luabind::functor<void>& new_delete>, const<luabind::functor<bool>& contact> );	// CGameObject

	void			disable_anomaly( bool<keep_update> );	// CCustomZone
};

class CSpaceRestrictor {
	CSpaceRestrictor();

	vector*					restrictor_center;
	property global_flags*	restrictor_type;
	property float			radius;

	void					schedule_register();
	void					schedule_unregister();
	bool					is_scheduled();
	bool					active_contact( u16<object_id> );
};

// not exported
enum EZoneState {
	eZoneStateIdle = 0,		//состояние зоны, когда внутри нее нет активных объектов
	eZoneStateAwaking = 1,		//пробуждение зоны (объект попал в зону)
	eZoneStateBlowout = 2,		//выброс
	eZoneStateAccumulate = 3,	//накапливание энергии, после выброса
	eZoneStateDisabled = 4,
	eZoneStateMax = 5
};

class CustomZone : CSpaceRestrictor {
	float		power( float<dist> );
	float		relative_power( float<dist> );

	property float	attenuation;
	property float	effective_radius;
	property float	hit_impulse_scale;
	property float	max_power;
	property u32	state_time;
	property u32	start_time;
	property u32	time_to_live;
	property bool	zone_active;
	property u32<EZoneState>	zone_state;
	
};

class ph_capture {
	const pulling	= 0;
	const captured	= 1;
	const released	= 2;
};

class CPHCapture {
	int<ph_capture*>	e_state;
	property float		capture_force;
	property float		distance;
	property bool		hard_mode;
	property float		pull_distance;
	property float		pull_force;
	property float		time_limit;
};

class CWeaponHUD {
	int				fire_bone;
	vector*			fire_point;
	vector*			fire_point2;
	IRenderVisual*	visual;
	matrix*			transform;
	bool			visible;
};

// do not exported
enum EWeaponAddonState {
	eWeaponAddonScope = 0x01,
	eWeaponAddonGrenadeLauncher = 0x02,
	eWeaponAddonSilencer = 0x04,
	eWeaponAddonGrip = 0x08,
	eWeaponAddonMagazine = 0x10,
	eWeaponAddonScopeMount = 0x20,
	//eVisUpdatesActivated = 0x40,
	eForcedNotexScope = 0x80
};
// do not exported
//возможность подключения аддонов
enum EWeaponAddonStatus {
	eAddonDisabled				= 0,	//нельзя присоеденить
	eAddonPermanent				= 1,	//постоянно подключено по умолчанию
	eAddonAttachable			= 2		//можно присоединять
};

class CWeapon : CInventoryItemObject {
	global_flags*	state;
	global_flags*	next_state;

	property float	cam_max_angle;
	property float	cam_relax_speed;
	property float	cam_relax_speed_ai;
	property float	cam_dispersion;
	property float	cam_dispersion_inc;
	property float	cam_dispertion_frac;
	property float	cam_max_angle_horz;
	property float	cam_step_angle_horz;

	property float	fire_dispersion_condition_factor;
	property float	misfire_probability;
	property float	misfire_condition_k;
	property float	condition_shot_dec;

	property float	PDM_disp_base;
	property float	PDM_disp_vel_factor;
	property float	PDM_disp_accel_factor;
	property float	PDM_crouch;
	property float	PDM_crouch_no_acc;

	property hit*	hit_type;
	property float	hit_impulse;
	property float	bullet_speed;
	property float	fire_distance;
	property float	fire_dispersion_base;
	property float	time_to_aim;
	property float	time_to_fire;
	property bool	use_aim_bullet;
	property float	hit_power;

	property float	ammo_mag_size;
	property bool	scope_dynamic_zoom;
	property bool	zoom_enabled;
	property float	zoom_factor;
	property float	zoom_rotate_time;
	property float	iron_sight_zoom_factor;
	property float	scope_zoom_factor;
	property float	zoom_rotation_factor;

	// переменные для подстройки положения аддонов из скриптов:
	property float	grenade_launcher_x;
	property float	grenade_launcher_y;
	property float	scope_x;
	property float	scope_y;
	property float	silencer_x;
	property float	silencer_y;

	property int<EWeaponAddonStatus>	scope_status;
	property int<EWeaponAddonStatus>	silencer_status;
	property int<EWeaponAddonStatus>	grenade_launcher_status;
	property LPCSTR	scope_name;
	property LPCSTR	silencer_name;
	property LPCSTR	grenade_launcher_name;

	bool			misfire;
	bool			zoom_mode;

	bool			is_second_zoom_offset_enabled;
	void			switch_scope();
	property float	scope_inertion_factor;

	property float	scope_lense_fov_factor;
	bool			second_vp_enabled();

	property int	ammo_elapsed;
	SRotation*		const_deviation;

	int				get_ammo_current( bool<use_item_to_spawn> );
	void			start_fire();
	void			stop_fire();
	void			start_fire2();
	void			stop_fire2();
	void			stop_shoothing();
	matrix*			get_particles_xform();
	vector*			get_fire_point();
	vector*			get_fire_point2();
	vector*			get_fire_direction();
	bool			ready_to_kill();
};

class CWeaponMagazined : CWeapon {
	int					shot_num;
	property int		queue_size;
	property int		shoot_effector_start;
	property int		cur_fire_mode;
	int					fire_mode;
	property Lua_table*	fire_modes;

	void				attach_addon( game_object*<addon>, bool<b_send_event> );
	void				detach_addon( char*<item_section_name>, boolM<b_spawn_item> );
};

class CWeaponMagazinedWGrenade : CWeaponMagazined {
	property int	gren_mag_size;

	bool			switch_gl();
};

class CMissile : CInventoryItemObject {
	property u32	destroy_time;
	property u32	destroy_time_max;
};

class CInventoryItem {
	EItemPlace*				item_place;
	property float			item_condition;
	property float			inv_weight;
	property global_flags*	m_flags;
	property bool			always_ungroupable;

	property float			psy_health_restore_speed;
	property float			radiation_restore_speed;

	property LPCSTR			inv_name;
	property LPCSTR			inv_name_short;
	property u32			cost;
	property u8				slot;
	property Lua_table*		slots;
	property LPCSTR			description;
};

class CInventoryItemObject : CInventoryItem, CGameObject {
};

class CTorch : CInventoryItemObject {
	CTorch();

	bool			on;
	void			enable(bool);
	void			switch();
	IRender_Light*	get_light( int<target> );
	void			set_animation( LPCSTR );
	void			set_angle( float );
	void			set_brightness( float );
	void			set_color( Fcolor* );
	void			set_rgb( float, float, float );
	void			set_range( float );
	void			set_texture( LPCSTR );
	void			set_virtual_size( float );

	bool			nvd_on;
	void			enable_nvd( bool );
	void			switch_nvd();
	game_object*	get_torch_obj();
};

class CInventory {
	property u32	max_belt;
	property float	max_weight;
	property float	take_dist;
	float			total_weight;
	game_object*	active_item;
	game_object*	selected_item;
	game_object*	target;
};

class IInventoryBox {
	game_object*	object( u32 );
	game_object*	object( LPCSTR );
	u32				object_count();
	bool			empty();
};
class CInventoryBox : IInventoryBox, CGameObject {
};

class CInventoryContainer : IInventoryBox, CInventoryItemObject {
	u32			cost;
	float		weight;
	bool		is_opened;

	void		open();
	void		close();
};

class CInventoryOwner {
	CInventory*		inventory;
	bool			talking;
	property bool	allow_talk;
	property bool	allow_trade;
	property u32	raw_money;
	u32				money;

	LPCSTR			Name();
	void			SetName( LPCSTR<name> );
};

class CCustomMonster : CEntityAlive {
	property bool		visible_for_zones;

	u32					get_dest_vertex_id();
	CAnomalyDetector*	anomaly_detector();
};

class CBaseMonster : CInventoryOwner, CEntityAlive {
	property bool	agressive;
	property bool	angry;
	property bool	damaged;
	property bool	grownlig;
	property bool	run_turn_left;
	property bool	run_turn_right;
	property bool	sleep;
	property bool	state_invisible;
};

class CCustomOutfit : CInventoryItemObject {
	property float	additional_inventory_weight;
	property float	additional_inventory_weight2;
	property float	power_loss;
	property float	burn_protection;
	property float	strike_protection;
	property float	shock_protection;
	property float	wound_protection;
	property float	radiation_protection;
	property float	telepatic_protection;
	property float	chemical_burn_protection;
	property float	explosion_protection;
	property float	fire_wound_protection;
	property float	wound_2_protection;
	property float	physic_strike_protection;
};

class CHitImmunity {
	property float	burn_immunity;
	property float	strike_immunity;
	property float	shock_immunity;
	property float	wound_immunity;
	property float	radiation_immunity;
	property float	telepatic_immunity;
	property float	chemical_burn_immunity;
	property float	explosion_immunity;
	property float	fire_wound_immunity;
	property float	wound_2_immunity;
	property float	physic_strike_immunity;
};

class SEntityState {
	bool	crouch;
	bool	fall;
	bool	jump;
	bool	sprint;

	float	velocity();
	float	a_velocity();
};

class CEntityCondition {
	float			fdelta_time();
	bool			has_valid_time();

	property float	health;
	property float	max_health;
	property float	power;
	property float	power_max;
	property float	psy_health;
	property float	psy_health_max;
	property float	radiation;
	property float	radiation_max;
	property float	morale;
	property float	morale_max;
	property float	min_wound_size;
	bool			is_bleeding;
	property float	health_hit_part;
	property float	power_hit_part;
};

class CActorConditionBase {
	property float	health;
	property float	health_max;
	property float	alcohol_health;
	property float	alcohol_v;
	property float	power_v;
	property float	satiety;
	property float	satiety_v;
	property float	satiety_health_v;
	property float	satiety_power_v;

	property float	thirst;
	property float	thirst_v;
	property float	thirst_health_v;
	property float	thirst_power_v;

	property float	max_power_leak_speed;
	property float	jump_power;
	property float	stand_power;
	property float	walk_power;
	property float	jump_weight_power;
	property float	walk_weight_power;
	property float	overweight_walk_k;
	property float	overweight_jump_k;
	property float	accel_k;
	property float	sprint_k;
	property float	max_walk_weight;

	property float	health_hit_part;
	property float	power_hit_part;

	property float	limping_power_begin;
	property float	limping_power_end;
	property float	cant_walk_power_begin;
	property float	cant_walk_power_end;
	property float	cant_spint_power_begin;
	property float	cant_spint_power_end;
	property float	limping_health_begin;
	property float	limping_health_end;

	bool			limping;
	bool			cant_walk;
	bool			cant_sprint;
	property float	radiation_v;
	property float	psy_health_v;
	property float	morale_v;
	property float	radiation_health_v;
	property float	bleeding_v;
	property float	wound_incarnation_v;
	property float	health_restore_v;

	float			get_wound_size();
	float			get_wound_total_size();
};
class CActorCondition : CActorConditionBase, CEntityCondition {
};

class CPHMovementControl {
	property float ph_mass;
	property float crash_speed_max;
	property float crash_speed_min;
	property float collision_damage_factor;
	property float air_control_param;
	property float jump_up_velocity;
};

class SRotation {
	SRotation();
	SRotation( float<yaw>, float<pitch>, float<roll> );

	property float	pitch;
	property float	yaw;
	property float	roll;

	vector*			get_dir( bool<v_inverse> );
	void			set_dir( vector, bool<v_inverse> );
	void			set( SRotation* );
	void			set( float<yaw>, float<pitch>, float<roll> );
};

class CActorBase : CInventoryOwner, CGameObject {
	property CActorCondition*		condition;
	property CHitImmunity*			immunities;
	property float					hit_slowmo;
	property float					hit_probability;
	property float					walk_accel;

	property float					run_coef;
	property float					run_back_coef;
	property float					walk_back_coef;
	property float					crouch_coef;
	property float					climb_coef;
	property float					sprint_koef;
	property float					walk_strafe_coef;
	property float					run_strafe_coef;
	property float					disp_base;
	property float					disp_aim;
	property float					disp_vel_factor;
	property float					disp_accel_factor;
	property float					disp_crouch_factor;
	property float					disp_crouch_no_acc_factor;

	property CPHMovementControl*	movement;
	property float					jump_speed;
	property SEntityState*			state;
	property SRotation*				orientation;

	void							block_action( key_bindings* );
	void							unblock_action( key_bindings* );
	void							press_action( DIK_keys* );
	void							hold_action( DIK_keys* );
	void							release_action( DIK_keys* );
	bool							is_zoom_aiming_mode();

	u32<EMoveCommand>				get_body_state();
	bool							is_actor_normal();
	bool							is_actor_crouch();
	bool							is_actor_creep();
	bool							is_actor_climb();
	bool							is_actor_walking();
	bool							is_actor_running();
	bool							is_actor_sprinting();
	bool							is_actor_crouching();
	bool							is_actor_creeping();
	bool							is_actor_climbing();
	bool							is_actor_moving();
	void							UpdateArtefactsOnBelt();
};
class CActor : CActorBase, CEntityAlive {
};

class ITexture {
	void load( char*<name> );
	char* get_name();
};

class CAnomalyDetector {
	property float		Anomaly_Detect_Radius;
	property float		Anomaly_Detect_Time_Remember;
	property float		Anomaly_Detect_Probability;
	bool				is_active;

	void				activate( bool<force> );
	void				deactivate( bool<force> );
	void				remove_all_restrictions();
	void				remove_restriction( u16<id> );
};

class CPatrolPoint {
	CPatrolPoint();

	property vector*	m_position;
	property u32		m_flags;
	property u32		m_level_vertex_id;
	property u32		m_game_vertex_id;
	property shared_str	m_name;

	vector*	 			position();
};

class CPatrolPath {
	CPatrolPath();

	CPatrolPoint*	add_point( vector*<pos> );
	CPatrolPoint*	point( u32<index> );
	void			add_vertex( CPatrolPoint*<point>, u32<level_vertex_id> );
};

class CCameraBase {
	property float		aspect;
	vector*				direction;
	property float		fov;
	property vector*	position;

	property vector2*	lim_yaw;
	property vector2*	lim_pitch;
	property vector2*	lim_roll;

	property float		yaw;
	property float		pitch;
	property float		roll;
};

class vector2 {
	property float	x;
	property float	y;

	vector2();

	vector2* 		set( float<x>, float<y> );
	vector2* 		set( vector2* );
};

class CEnvDescriptor {
	property float		fog_density;
	property float		fog_distance;
	property float		far_plane;
	property vector*	sun_dir;

	void				set_env_ambient( LPCSTR<sect>, CEnvironment*<parent> );
};

class CEnvironment {
	CEnvDescriptor* current();
};

class CPHCall {
	void set_pause( u32<ms> );
};

class rq_result {
	float			range;
	game_object*	object;
	int				element;
	bool			result;
	SGameMtl*		mtl;
};

class rq_target {
	const rqtNone		= 0;
	const rqtObject		= 1;
	const rqtStatic		= 2;
	const rqtShape		= 4;
	const rqtObstacle	= 8;
	const rqtBoth		= (rqtObject|rqtStatic);
	const rqtDyn		= (rqtObject|rqtShape|rqtObstacle);
};

class SGameMtl {
	LPCSTR					m_Name;
	LPCSTR					m_Desc;
	flags32*<SGameMtlFlags>	Flags;
	float					fPHFriction;
	float					fPHDamping;
	float					fPHSpring;
	float					fPHBounceStartVelocity;
	float					fPHBouncing;
	float					fFlotationFactor;
	float					fShootFactor;
	float					fBounceDamageFactor;
	float					fInjuriousSpeed;
	float					fVisTransparencyFactor;
	float					fSndOcclusionFactor;
};

class SGameMtlFlags {
	const flActorObstacle		= 4096;			// 1<<12
	const flBloodmark			= 16;			// 1<<4
	const flBounceable			= 4;			// 1<<2
	const flClimable			= 32;			// 1<<5
	const flDynamic				= 256;			// 1<<8
	const flInjurious			= 268435456;	// 1<<28
	const flLiquid				= 512;			// 1<<9
	const flPassable			= 128;			// 1<<7
	const flSlowDown			= 2147483648;	// 1<<31
	const flSuppressShadows		= 1024;			// 1<<10
	const flSuppressWallmarks	= 2048;			// 1<<11
};

class CUIWindow {
	float		GetPosTop();
	float		GetPosLeft();
	void		DetachFromParent();
	float		GetMousePosX();
	float		GetMousePosY();
	CUIWindow*	GetParent();
	void		GetWndRect( Frect*<rect> );
	bool		IsChild( CUIWindow*<pPossibleChild> );
	CUIWindow*	FindChild( shared_str<name>, u32<max_nested> );
	CUIButton*	GetButton();
	CUIStatic*	GetCUIStatic();
	void		GetAbsoluteRect( Frect*<rect> );
};

class CUIComboBox : CUIWindow {
	CUIListBoxItem*	AddItem( LPCSTR<str> );
	LPCSTR			GetText();
};

class CIconParams {
	CIconParams( LPCSTR<section> )

	int		icon_group;
	int		grid_width;
	int		grid_height;
	int		grid_x;
	int		grid_y;
	LPCSTR	icon_name;

	Frect*	original_rect();
	void	set_shader( CUIStatic*<img> );
};

// do not exported
enum EActorCameras {
	eacFirstEye		= 0,
	eacLookAt		= 1,
	eacFreeLook		= 2,
	eacMaxCam		= 3,
};

// do not exported
enum EMoveCommand
{
	mcFwd		= 1,
	mcBack		= 2,
	mcLStrafe	= 4,
	mcRStrafe	= 8,
	mcCrouch	= 16,
	mcAccel		= 32,
	mcTurn		= 64,
	mcJump		= 128,
	mcFall		= 256,
	mcLanding	= 512,
	mcLanding2	= 1024,
	mcClimb		= 2048,
	mcSprint	= 4096,
	mcLLookout	= 8192,
	mcRLookout	= 16384,
	mcAnyMove	= (mcFwd|mcBack|mcLStrafe|mcRStrafe),
	mcAnyAction = (mcAnyMove|mcJump|mcFall|mcLanding|mcLanding2), //mcTurn|
	mcAnyState	= (mcCrouch|mcAccel|mcClimb|mcSprint),
	mcLookout	= (mcLLookout|mcRLookout),
};

class path : stdfs* {
	char	full_path_name;
	char	full_filename;
	char	short_filename;
	char	extension;
	int		last_write_time;
	char	last_write_time_string;
	char	last_write_time_string_short;
};
	


//List of the namespaces exported to LUA

namespace  {
	Lua_table*		texture_find( char*<name> );	//[texture_name] = ITexture*
	CCameraBase*	actor_camera( u16<EActorCameras*> );

	void			set_artefact_slot( u32<i>, float<x>, float<y>, float<z> );
	void			set_anomaly_slot( u32<i>, float<x>, float<y>, float<z> );
	void			set_detector_mode( int<_one>, int<_two> );
	void			update_inventory_window();
	void			update_inventory_weight();

	int<key_bindings*>	dik_to_bind( int<DIK_keys*> );
	LPCSTR				dik_to_keyname( int<DIK_keys*> );
	int<DIK_keys*>		keyname_to_dik( LPCSTR<key_name> );

	namespace stdfs {
		void directory_iterator( const char* dir, const luabind::functor<void> &iterator_func(path*) );
		void recursive_directory_iteratorconst char* dir, const luabind::functor<void> &iterator_func(path*) );
	};

    namespace level {
		bool					is_removing_objects();
		shared_str				get_weather_prev();
		u32						get_weather_last_shift();
		void					set_weather_next( shared_str<name> );
		void					start_weather_fx_from_time( shared_str<name>, float<time> );
		float					get_wfx_time();
		void					stop_weather_fx();

		bool					game_indicators_shown();
		flags32*<psHUD_Flags>	get_hud_flags();

		void					set_ignore_game_state_update();

		CUIWindow*				get_inventory_wnd();
		CUIWindow*				get_talk_wnd();
		CUIWindow*				get_trade_wnd();
		CUIWindow*				get_pda_wnd();
		CUIWindow*				get_car_body_wnd();
		CUIWindow*				get_change_level_wnd();

		game_object*			get_second_talker();
		game_object*			get_car_body_target();

		rq_result*				ray_query( vector*<start>, vector*<dir>, float<range>, rq_target*<tgt>, game_object*<ignore> );

		u32						vertex_id( vector*<vec> );
		u32						vertex_id( u32<node>, vector<vec> );

		void					advance_game_time( u32<ms> );

		float					get_target_dist();
		game_object*			get_target_obj();
		rq_result*				get_current_ray_query();

		void					send_event_key_press( int<dik> );
		void					send_event_key_release( int<dik> );
		void					send_event_key_hold( int<dik> );
		void					send_event_mouse_wheel( int<vol> );

		void					change_level( GameGraph::_GRAPH_ID<game_vertex_id>, u32<level_vertex_id>, vector*<pos>, vector*<dir> );
		void					set_cam_inert( float );
		void					set_monster_relation( LPCSTR<(MONSTER_COMMUNITY_ID)from>, LPCSTR<(MONSTER_COMMUNITY_ID)to>, int<rel> );
		void					patrol_path_add( LPCSTR<patrol_path>, CPatrolPath*<path> );
		void					patrol_path_remove( LPCSTR<patrol_path> );
		bool					valid_vertex_id( u32<level_vertex_id> );
		u32						vertex_count();
		void					disable_vertex( u32<vertex_id> );
		void					enable_vertex( u32<vertex_id> );
		bool					is_accessible_vertex_id( u32<vertex_id> );
		void					iterate_vertices_inside( vector<center>, float<radius>, bool<partially_inside>, Lua_function*<func(vertex_id)> );
		void					iterate_vertices_border( vector<center>, float<radius>, Lua_function*<func(vertex_id)> );
		float					set_blender_mode_main( float );
		float					get_blender_mode_main();
		void					set_shader_params( matrix*<m_params> )
		matrix*					get_shader_params();
	};

	namespace actor_stats {
		void	add_points_str( LPCSTR<sect>, LPCSTR<detail_key>, LPCSTR<str_value> );
		int		get_actor_ranking();
	};

	namespace relation_registry {
		int		get_personal_goodwill( int<who_id>, int<to_whom_id> );
		void	set_personal_goodwill( int<who_id>, int<to_whom_id>, int<amount> );
		void	change_personal_goodwill( int<who_id>, int<to_whom_id>, int<amount> );
		void	clear_personal_goodwill( int<who_id>, int<to_whom_id> );
		void	clear_personal_relations( int<who_id> );
	};
};