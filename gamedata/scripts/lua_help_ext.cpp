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
	property satiety;

	// CEntityAlive
	bool	is_alive();
	bool	is_wounded();
	// CActor
	float	get_inventory_weight();
	float	get_actor_max_weight();
	float	get_actor_max_walk_weight();
	void	set_actor_max_weight(float);
	void	set_actor_max_walk_weight(float);
	bool	is_actor_running();
	bool	is_actor_crouching();
	bool	is_actor_sprinting();
	bool	is_actor_creeping();
	bool	is_actor_climbing();
	bool	is_actor_walking();
	float	get_actor_float(int<shift>);
	void	set_actor_float(NULL, float<value>, int<shift>);
	void	set_actor_condition_float(NULL, float<value>, int<shift>);
	int		get_actor_int(NULL, int<shift>);
	// CInventoryItem
	void	set_inventory_item_flags(int<mask>, bool<value>);
	bool	has_inventory_item_flags(int<mask>);
	void	set_custom_color_ids(int<color_index>);
	int		get_slot();
	void	set_slot(int<slot>);
	void	set_cost(int<cost>);
	float	get_weight();
	void	set_weight(float<weight>);
	// CWeaponAmmo
	int		get_ammo_left();
	// CWeapon
	int		get_addon_flags();
	void	set_addon_flags(int<flag>);
	void	add_addon_flags(int<flag>);
	int		get_ammo_type();
	// CInventoryBox
	game_object*	object_from_inv_box(int<index>);
	int				inv_box_count();
	
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

class Frect {
	Frect*	mul(float<x>, float<y>*);
	Frect*	div(float<x>, float<y>*);
	float	width();
	float	height();
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
	const DIK_LMOUSE			= 337;
	const DIK_RMOUSE			= 338;
	const DIK_WMOUSE			= 339;
};

class CGameFont {
	const alVTop	= 0;
	const alVCenter	= 1;
	const alVBottom	= 2;
};

class CUIStatic : CUIWindow {
	void	SetTextComplexMode(bool);
	void	SetVTextAlign(int<CGameFont*>);
};

class CUIScriptWnd : CUIDialogWnd,DLL_Pure {
	void			AddCallbackEx(char<ui_name>, char<ui_event>, Lua_function<func>, <args>*);
	void			ClearCallbacks();
	void			RegisterChild(CUIScriptWnd*);
	CUIScriptWnd*	InitEditBoxEx(CUIWindow*<stat>, float<pos_x>, float<pos_y>, float<width>*, char<type>*);
	CUIScriptWnd*	InitSpinNum(CUIWindow*<stat>, float<pos_x>, float<pos_y>, float<width>*, Lua_table*<params>);
	CUIScriptWnd*	InitSpinStr(CUIWindow*<stat>, float<pos_x>, float<pos_y>, float<width>*, Lua_table*<params>);
};

End of list of the classes exported to LUA


List of the namespaces exported to LUA

namespace {
	void			set_input_language(int<mode>);	// 1 - RU, 0 - EN
	int				get_input_language();
    int<DIK_keys*>	bind_to_dik(int<key_bindings*>);
	
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