// XE Wiki: https://xray-engine.org/index.php?title=X-Ray_extensions

// List of the classes exported to LUA

class callback {
	// CActor
	const on_key_press                 = 123
	const on_key_release               = 124
	const on_key_hold                  = 125
	const on_mouse_wheel               = 126
	const on_mouse_move                = 127
	const on_anomaly_hit               = 128
	const on_drop_inv_item             = 129
	const on_belt                      = 130
	const on_ruck                      = 131
	const on_slot                      = 132
	const on_select_item               = 133
	const on_create_cell_item          = 136
	const on_attach_vehicle            = 137
	const on_vehicle_exit              = 138
	const on_detach_vehicle            = 139
	const after_save                   = 140
	const on_focus_item                = 141
	const on_focus_lost_item           = 142
	const on_grouping_item             = 143
	const on_mob_hit_to_actor          = 144
	const on_change_goodwill           = 145
	const on_before_use_item           = 156
	const on_animation_end             = 157
	const pda_contact                  = 180
	// CTorch
	const on_switch_torch              = 134
	// CAIStalker
	const on_set_dest_vertex           = 135
	// CInventoryBox
	const on_inv_box_put_item          = 151
	// CEntityAlive
	const entity_alive_before_hit      = 152
	// CWeapon
	const update_addons_visibility     = 154
	const update_hud_addons_visibility = 155
};

class game_object {
	// CGameObjet
	float			get_go_float(int<offset>);
	void			set_go_float(vector*, float<value>, int<offset>);
	int				get_go_int();
	int				get_go_int(string, int<offset>)
	void			set_go_int(int<value>, int<offset>)
	int				get_go_int16(string, int<offset>)
	void			set_go_int16(int<value>, int<offset>)
	string			get_go_shared_str();	// offset set with set_int_arg0(int<offset>)
	int				cast_car();
	int				cast_game_object();
	int				cast_hud_item();
	int				cast_inventory_box();
	int				cast_inventory_item();
	int				cast_weapon();
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
	bool			is_weapon_gl();
	bool			is_inventory_box();
	bool			is_medkit();
	bool			is_eatable_item();
	bool			is_antirad();
	bool			is_outfit();
	bool			is_scope();
	bool			is_silencer();
	bool			is_grenade_launcher();
	bool			is_weapon_magazined();
	bool			is_space_restrictor();
	bool			is_stalker();
	bool			is_anomaly();
	bool			is_monster();
	bool			is_script_zone();
	bool			is_projector();
	bool			is_trader();
	bool			is_hud_item();
	bool			is_food_item();
	bool			is_artefact();
	bool			is_ammo();
	bool			is_missile();
	bool			is_physics_shell_holder();
	bool			is_grenade();
	bool			is_bottle_item();
	bool			is_hanging_lamp();
	bool			is_knife();
	bool			is_binoculars();
	bool			is_weapon_pistol();
	bool			is_weapon_shotgun();
	float			radius();
	// CActor
	property		satiety;
	float			get_inventory_weight();
	float			get_actor_max_weight();
	float			get_actor_max_walk_weight();
	void			set_actor_max_weight(float);
	void			set_actor_max_walk_weight(float);
	void			set_sprint_factor(float<factor>);
	float			get_sprint_factor();
	int				actor_body_state();
	float			get_actor_take_dist();
	void			set_actor_take_dist(float);
	int				belt_count();
	int				ruck_count();
	int				slot_number();
	game_object*	item_on_belt(int);
	game_object*	item_in_ruck(int);
	bool			is_on_belt(game_object*);
	bool			is_in_ruck(game_object*);
	bool			is_in_slot(game_object*);
	void			move_to_ruck(game_object*);
	void			move_to_belt(game_object*);
	void			move_to_slot(game_object*);
	void			move_to_slot_and_activate(game_object*);
	bool			is_actor_normal();
	bool			is_actor_crouch();
	bool			is_actor_creep();
	bool			is_actor_climb();
	bool			is_actor_running();
	bool			is_actor_crouching();
	bool			is_actor_sprinting();
	bool			is_actor_creeping();
	bool			is_actor_climbing();
	bool			is_actor_walking();
	float			get_actor_float(int<offset>);
	void			set_actor_float(vector*, float<value>, int<offset>);
	float			get_actor_condition_float(int);
	void			set_actor_condition_float(vector*, float<value>, int<offset>);
	string			get_actor_shared_str();	// offset set with set_int_arg0(int<offset>)
	int				get_actor_int(string, int<offset>);
	float			get_camera_fov();
	void			set_camera_fov(float<fov>);
	float			get_hud_fov();
	void			set_hud_fov(float<fov>);
	void			set_actor_visual(string<visual>);
	void			open_inventory_box(game_object*<box>);
	void			enable_car_panel(bool);
	// CAIStalker, CActor
	string			specific_character();
	// CAIStalker
	bool			get_anomaly_invisibility();
	void			set_anomaly_invisibility(bool<visibility>);
	// CEntityAlive
	void			heal_wounds(float<factor>);
	void			update_condition();
	bool			is_alive();
	bool			is_wounded();
	// CProjector
	void			projector_on();
	void			projector_off();
	bool			projector_is_on();
	void			switch_projector(bool);
	// CInventoryItem
	float			get_inventory_item_float(int<offset>);
	void			set_inventory_item_float(vector, float<value>, int<offset>);
	int				get_inventory_item_int(string, int<offset>);
	void			set_inventory_item_int(int<value>, int<offset>);
	int				get_inventory_item_int8(string, int<offset>);
	void			set_inventory_item_int8(int<value>, int<offset>);
	int				get_inventory_item_int16(string, int<offset>);
	void			set_inventory_item_int16(int<value>, int<offset>);
	string			get_inventory_item_shared_str();	// offset set with set_int_arg0(int<offset>)
	int				set_inventory_item_shared_str(string<value>, int<offset>);
	void			set_inventory_item_flags(int<mask>, bool<value>);
	bool			has_inventory_item_flags(int<mask>);
	void			set_custom_color_ids(int<color_index>);
	int				get_slot();
	void			set_slot(int<slot>);
	void			set_cost(int<cost>);
	float			get_weight();
	void			set_weight(float<weight>);
	// CWeaponAmmo
	int				get_ammo_left();
	// CWeapon
	int				get_addon_flags();
	void			set_addon_flags(int<flag>);
	void			add_addon_flags(int<flag>);
	int				get_ammo_type();
	// CInventoryBox
	game_object*	object_from_inv_box(int<index>);
	int				inv_box_count();
	// CTorch
	void			switch_torch(bool<switch_on>);			//переключает фонарь.
	bool			is_torch_enabled();						//возвратит true, если фонарь включён.
	void			set_torch_range(float<range>);			//устанавливает дальность основного света фонаря.
	void			set_torch_color(vector<R, G, B>);		//устанавливает цвет основного света от фонаря.
	void			set_torch_omni_range(float<range>);		//устанавливает дальность амбиент-света фонаря.
	void			set_torch_omni_color(vector<R, G, B>);	//устанавливает цвет амбиент-света от фонаря.
	void			set_torch_glow_radius(float<radius>);	//устанавливает радиус глоу-эффекта от фонарика.
	void			set_torch_spot_angle(float<angle>);		//устанавливает радиус светового пятна от фонарика.
	void			set_torch_color_animator(string<path>);	//устанавливает путь до аниматора цвета.
	void			switch_night_vision(bool<switch_on>);	//переключает состояние ПНВ.
	// CSpaceRestrictor
	float			get_shape_radius();
};

class ini_file {
	char		r_string_ex(char<section>, char<line>, char<default_value>*);
	int			r_u32_ex(char<section>, char<line>, int<default_value>*);
	float		r_float_ex(char<section>, char<line>, float<default_value>*);
	int<clsid*>	r_clsid_ex(char<section>, char<line>);
	bool		r_bool_ex(char<section>, char<line>, bool<default_value>*);
	Lua_table*	r_list(char<section>, char<line>, bool<to_hash>*);
};

class net_packet {
	vector*		r_vec_q8();
	void		w_vec_q8(vector*);
	Lua_table*	r_qt_q8();			// {x = int, y = int, z= int, w = int}
	void		w_qt_q8(Lua_table*);
	Lua_table*	r_u64();			// {int,int,int,int,int,int,int,int}
	void		w_u64(Lua_table*);
	Lua_table*	r_vu8u8();
	void		w_vu8u8(Lua_table*);
	Lua_table*	r_vu32u8();
	void		w_vu32u8(Lua_table*);
	Lua_table*	r_vu32u16();
	void		w_vu32u16(Lua_table*);
	Lua_table*	r_tail();
	void		w_tail(Lua_table*);
	CTime*		r_CTime();
	void		w_CTime(CTime*);
};

class vector2 {
	vector2();

	property	x;
	property	y;

	vector2*	set(float<x>, float<y>);
	vector2*	add(vector2);
	vector2*	sub(vector2);
	vector2*	mul(float<x>, float<y>);
	vector2*	div(float<x>, float<y>);
	float		distance_to(vector2)
	float<x>,float<y>	get();
};

class Frect {
	Frect*		mul(float<x>, float<y>*);
	Frect*		div(float<x>, float<y>*);
	float		width();
	float		height();
	Frect*		shrink(float<x>, float<y>);
	Frect*		grow(float<x>, float<y>);
	Frect*		intersected(Frect*<check_rect>);
	vector2*	center();
};

class key_bindings {
	const kENGINE		= 15;
	const kACTIVE_JOBS	= 53;
	const kMAP			= 54;
	const kCONTACTS		= 55;
	const kEXT_1		= 56;
	const kUSE_BANDAGE	= 73;
	const kUSE_MEDKIT	= 74;
	const kQUICK_SAVE	= 75;
	const kQUICK_LOAD	= 76;
	const DUMMY			= 78;
};

class key_bindings {
	const DIK_keys.DUMMY		= 0;
	const DIK_LMOUSE			= 337;
	const DIK_RMOUSE			= 338;
	const DIK_WMOUSE			= 339;
};

class CGameFont {
	const alVTop	= 0;
	const alVCenter	= 1;
	const alVBottom	= 2;
};

class CUIWindow {
	void		DetachFromParent();
	void		BringToTop();
	void		Update();
	float<x>	GetVPos();
	float<y>	GetHPos();
	float<x>	GetCursorX();
	float<y>	GetCursorY();
	float<x>	GetAbsolutePosX();
	float<y>	GetAbsolutePosY();
};

class CUIComboBox : CUIWindow {
	void	AddItem(char<text>);
	char	GetText();
};

class CUIListWnd : CUIWindow {
	void	SetSelectedItem(int<index>);
};

class CUITrackBar : CUIWindow {
	float	GetFValue();
	bool	IsChanged();
};

class CUIStatic : CUIWindow {
	void		SetTextComplexMode(bool);
	void		SetVTextAlign(int<CGameFont*>);
	void		AdjustHeightToText();	// xml: adjust_height_to_text
	void		AdjustWeigthToText();	// xml: adjust_width_to_text
	void		SetTextPos(float<x>, float<y>);
	bool		CanRotate();
	vector2*	GetWndSize();
};

class CUIScriptWnd : CUIDialogWnd,DLL_Pure {
	void			AddCallbackEx(char<ui_name>, int<ui_events*>, Lua_function<func>, <args>*);
	void			ClearCallbacks();
	void			RegisterChild(CUIScriptWnd*);
	CUIScriptWnd*	InitEditBoxEx(CUIWindow*<stat>, float<pos_x>, float<pos_y>, float<width>*, char<type>*);
	CUIScriptWnd*	InitSpinNum(CUIWindow*<stat>, float<pos_x>, float<pos_y>, float<width>*, Lua_table*<params>);
	CUIScriptWnd*	InitSpinStr(CUIWindow*<stat>, float<pos_x>, float<pos_y>, float<width>*, Lua_table*<params>);
};

End of list of the classes exported to LUA


List of the namespaces exported to LUA

namespace {
	void			log1(char<message>);
	void			fail(char<message>);
	void			flush_log();
	void			set_input_language(int<mode>);	// 1 - RU, 0 - EN
	int				get_input_language();
    int<DIK_keys*>	bind_to_dik(int<key_bindings*>);
	void			set_extensions_flags(int<flags>);
	int<flags>		get_extensions_flags();
	void			set_actor_flags(int<>);
	int				get_actor_flags();
	void			set_trade_filtration_on();
	void			set_trade_filtration_off();
	void			set_manual_grouping_on();
	void			set_manual_grouping_off();
	void			set_manual_highlight_on();
	void			set_manual_highlight_off();
	int				get_manual_highlight();
	void			set_highlight_color(int, int);
	int				sum_args(int<arg1>, int<arg2>);
	int				sub_args(int<arg1>, int<arg2>);
	int<goodwill>	GetGoodwill(int<who_id>, int<to_whom_id>);
	void			update_inventory_window();
	void			print_level_time();
	void			print_alife_time();
	void			screenshot0();
	void			screenshot1();
	void			screenshot2();
	void			screenshot3();
	
	namespace level {
		const invalid_vertex_id = 4294967296;

		void		change_game_time(int<minutes>, int<hours>, int<days>);
		int			vertex_id_by_pos( vector*<position> );
	};

	namespace relation_registry {
		int			get_goodwill(int<who_id>, int<to_whom_id>);
		void		set_goodwill(int<who_id>, int<to_whom_id>, int<goodwill>);
		void		change_goodwill(int<who_id>, int<to_whom_id>, int<goodwill_change>);
	};
};