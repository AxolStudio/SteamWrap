package steamwrap;
import cpp.Lib;
import steamwrap.helpers.Loader;
import steamwrap.helpers.MacroHelper;

class ControllerAPI
{
	/**
	 * Whether the controller API is initialized or not. If false, all calls will fail.
	 */
	public var active(default, null):Bool = false;
	
	private function new(CustomTrace:String->Void)
	{
		#if sys		//TODO: figure out what targets this will & won't work with and upate this guard
		
		if (active) return;
		
		customTrace = CustomTrace;
		
		try
		{
			//Old-school CFFI calls:
			SteamWrap_GetConnectedControllers = cpp.Lib.load("steamwrap", "SteamWrap_GetConnectedControllers", 0);
			SteamWrap_GetDigitalActionOrigins = cpp.Lib.load("steamwrap", "SteamWrap_GetDigitalActionOrigins", 3);
			SteamWrap_GetAnalogActionOrigins = cpp.Lib.load("steamwrap", "SteamWrap_GetAnalogActionOrigins", 3);
			SteamWrap_InitControllers = cpp.Lib.load("steamwrap", "SteamWrap_InitControllers", 0);
			SteamWrap_ShutdownControllers = cpp.Lib.load("steamwrap", "SteamWrap_ShutdownControllers", 0);
		}
		catch (e:Dynamic)
		{
			customTrace("Running non-Steam version (" + e + ")");
			return;
		}
		
		// if we get this far, the dlls loaded ok and we need Steam controllers to init.
		// otherwise, we're trying to run the Steam version without the Steam client
		active = SteamWrap_InitControllers();
		
		#end
	}
	
	/*************PUBLIC***************/

	/**
	 * Reconfigure the controller to use the specified action set (ie 'Menu', 'Walk' or 'Drive')
	 * This is cheap, and can be safely called repeatedly. It's often easier to repeatedly call it in
	 * your state loops, instead of trying to place it in all of your state transitions.
	 * 
	 * @param	controller	handle received from getConnectedControllers()
	 * @param	actionSet	handle received from getActionSetHandle()
	 * @return	1 = success, 0 = failure
	 */
	public function activateActionSet(controller:Int, actionSet:Int):Int {
		if (!active) return 0;
		return SteamWrap_ActivateActionSet.call(controller, actionSet);
	}
	
	/**
	 * Get the handle of the current action set
	 * 
	 * @param	controller	handle received from getConnectedControllers()
	 * @return	handle of the current action set
	 */
	public function getCurrentActionSet(controller:Int):Int {
		if (!active) return -1;
		return SteamWrap_GetCurrentActionSet.call(controller);
	}
	
	/**
	 * Lookup the handle for an Action Set. Best to do this once on startup, and store the handles for all future API calls.
	 * 
	 * @param	name identifier for the action set specified in your vdf file (ie, 'Menu', 'Walk' or 'Drive')
	 * @return	action set handle
	 */
	public function getActionSetHandle(name:String):Int {
		if (!active) return -1;
		return SteamWrap_GetActionSetHandle.call(name);
	}
	
	/**
	 * Returns the current state of the supplied analog game action
	 * 
	 * @param	controller	handle received from getConnectedControllers()
	 * @param	action	handle received from getActionSetHandle()
	 * @param	data	existing ControllerAnalogActionData structure you want to fill (optional) 
	 * @return	data structure containing analog x,y values & other data
	 */
	public function getAnalogActionData(controller:Int, action:Int, ?data:ControllerAnalogActionData):ControllerAnalogActionData {
		if (data == null)
		{
			data = new ControllerAnalogActionData();
		}
		
		if (!active) return data;
		
		data.bActive = SteamWrap_GetAnalogActionData.call(controller, action);
		data.eMode = cast SteamWrap_GetAnalogActionData_eMode.call(0);
		data.x = SteamWrap_GetAnalogActionData_x.call(0);
		data.y = SteamWrap_GetAnalogActionData_y.call(0);
		
		return data;
	}
	
	/**
	 * Lookup the handle for an analog (continuos range) action. Best to do this once on startup, and store the handles for all future API calls.
	 * 
	 * @param	name	identifier for the action specified in your vdf file (ie, 'Jump', 'Fire', or 'Move')
	 * @return	action analog action handle
	 */
	public function getAnalogActionHandle(name:String):Int {
		if (!active) return -1;
		return SteamWrap_GetAnalogActionHandle.call(name);
	}
	
	/**
	 * Get the origin(s) for an analog action with an action set. Use this to display the appropriate on-screen prompt for the action.
	 * NOTE: Users can change their action origins at any time, and Valve says this is a cheap call and recommends you poll it continuosly
	 * to update your on-screen glyph visuals, rather than calling it rarely and caching the values.
	 * 
	 * @param	controller	handle received from getConnectedControllers()
	 * @param	actionSet	handle received from getActionSetHandle()
	 * @param	action	handle received from getAnalogActionHandle()
	 * @param	originsOut	existing array of EControllerActionOrigins you want to fill (optional)
	 * @return the number of origins supplied in originsOut.
	 */
	
	public function getAnalogActionOrigins(controller:Int, actionSet:Int, action:Int, ?originsOut:Array<EControllerActionOrigin>):Int {
		if (!active) return -1;
		var str:String = SteamWrap_GetAnalogActionOrigins(controller, actionSet, action);
		var strArr:Array<String> = str.split(",");
		
		var result = 0;
		
		//result is the first value in the array
		if(strArr != null && strArr.length > 0){
			result = Std.parseInt(strArr[0]);
		}
		
		if (strArr.length > 1 && originsOut != null) {
			for (i in 1...strArr.length) {
				originsOut[i] = strArr[i];
			}
		}
		
		return result;
	}
	
	/**
	 * Enumerate currently connected controllers
	 * 
	 * NOTE: the native steam controller handles are uint64's and too large to easily pass to Haxe,
	 * so the "true" values are left on the C++ side and haxe only deals with 0-based integer indeces
	 * that map back to the "true" values on the C++ side
	 * 
	 * @return controller handles
	 */
	public function getConnectedControllers():Array<Int> {
		if (!active) return [];
		var str:String = SteamWrap_GetConnectedControllers();
		var arrStr:Array<String> = str.split(",");
		var intStr = [];
		for (astr in arrStr) {
			intStr.push(Std.parseInt(astr));
		}
		return intStr;
	}
	
	/**
	 * Returns the current state of the supplied digital game action
	 * 
	 * @param	controller	handle received from getConnectedControllers()
	 * @param	action	handle received from getDigitalActionHandle()
	 * @return
	 */
	public function getDigitalActionData(controller:Int, action:Int):ControllerDigitalActionData {
		if (!active) return new ControllerDigitalActionData(0);
		return new ControllerDigitalActionData(SteamWrap_GetDigitalActionData.call(controller, action));
	}
	
	/**
	 * Lookup the handle for a digital (true/false) action. Best to do this once on startup, and store the handles for all future API calls.
	 * 
	 * @param	name	identifier for the action specified in your vdf file (ie, 'Jump', 'Fire', or 'Move')
	 * @return	digital action handle
	 */
	public function getDigitalActionHandle(name:String):Int {
		if (!active) return -1;
		return SteamWrap_GetDigitalActionHandle.call(name);
	}
	
	/**
	 * Get the origin(s) for a digital action with an action set. Use this to display the appropriate on-screen prompt for the action.
	 * 
	 * @param	controller	handle received from getConnectedControllers()
	 * @param	actionSet	handle received from getActionSetHandle()
	 * @param	action	handle received from getDigitalActionHandle()
	 * @param	originsOut	existing array of EControllerActionOrigins you want to fill (optional)
	 * @return the number of origins supplied in originsOut.
	 */
	
	public function getDigitalActionOrigins(controller:Int, actionSet:Int, action:Int, ?originsOut:Array<EControllerActionOrigin>):Int {
		if (!active) return 0;
		var str:String = SteamWrap_GetDigitalActionOrigins(controller, actionSet, action);
		var strArr:Array<String> = str.split(",");
		
		var result = 0;
		
		//result is the first value in the array
		if(strArr != null && strArr.length > 0){
			result = Std.parseInt(strArr[0]);
		}
		
		if (strArr.length > 1 && originsOut != null) {
			for (i in 1...strArr.length) {
				originsOut[i] = strArr[i];
			}
		}
		
		return result;
	}
	
	/**
	 * Must be called when ending use of this API
	 */
	public function shutdown()
	{
		SteamWrap_ShutdownControllers();
		active = false;
	}
	
	//PRIVATE:
	
	private var customTrace:String->Void;
	
	//Old-school CFFI calls:
	private var SteamWrap_InitControllers:Dynamic;
	private var SteamWrap_ShutdownControllers:Dynamic;
	private var SteamWrap_GetConnectedControllers:Dynamic;
	private var SteamWrap_GetDigitalActionOrigins:Dynamic;
	private var SteamWrap_GetAnalogActionOrigins:Dynamic;
	
	//CFFI PRIME calls
	private var SteamWrap_ActivateActionSet       = Loader.load("SteamWrap_ActivateActionSet","iii");
	private var SteamWrap_GetCurrentActionSet     = Loader.load("SteamWrap_GetCurrentActionSet","ii");
	private var SteamWrap_GetActionSetHandle      = Loader.load("SteamWrap_GetActionSetHandle","ci");
	private var SteamWrap_GetAnalogActionData     = Loader.load("SteamWrap_GetAnalogActionData", "iii");
	private var SteamWrap_GetAnalogActionHandle   = Loader.load("SteamWrap_GetAnalogActionHandle","ci");
	private var SteamWrap_GetDigitalActionData    = Loader.load("SteamWrap_GetDigitalActionData", "iii");
		private var SteamWrap_GetAnalogActionData_eMode = Loader.load("SteamWrap_GetAnalogActionData_eMode", "ii");
		private var SteamWrap_GetAnalogActionData_x     = Loader.load("SteamWrap_GetAnalogActionData_x", "if");
		private var SteamWrap_GetAnalogActionData_y     = Loader.load("SteamWrap_GetAnalogActionData_y", "if");
	private var SteamWrap_GetDigitalActionHandle  = Loader.load("SteamWrap_GetDigitalActionHandle","ci");
}

abstract ControllerDigitalActionData(Int) from Int to Int{
	
	public function new(i:Int) {
		this = i;
	}
	
	public var bState(get, never):Bool;
	private function get_bState():Bool{return this & 0x1 == 0x1;}
	
	public var bActive(get, never):Bool;
	private function get_bActive():Bool{return this & 0x10 == 0x10;}
}

class ControllerAnalogActionData
{
	public var eMode:EControllerSourceMode = NONE;
	public var x:Float = 0.0;
	public var y:Float = 0.0;
	public var bActive:Int = 0;
	
	public function new(){}
}

@:enum abstract EControllerActionOrigin(Int) {
	
	public static var fromStringMap(default, null):Map<String, EControllerActionOrigin>
		= MacroHelper.buildMap("steamwrap.EControllerActionOrigin");
	
	public static var toStringMap(default, null):Map<EControllerActionOrigin, String>
		= MacroHelper.buildMap("steamwrap.EControllerActionOrigin", true);
		
	public var NONE = 0;
	public var A = 1;
	public var B = 2;
	public var X = 3;
	public var Y = 4;
	public var LEFTBUMPER= 5;
	public var RIGHTBUMPER= 6;
	public var LEFTGRIP = 7;
	public var RIGHTGRIP = 8;
	public var START = 9;
	public var BACK = 10;
	public var LEFTPAD_TOUCH = 11;
	public var LEFTPAD_SWIPE = 12;
	public var LEFTPAD_CLICK = 13;
	public var LEFTPAD_DPADNORTH = 14;
	public var LEFTPAD_DPADSOUTH = 15;
	public var LEFTPAD_DPADWEST = 16;
	public var LEFTPAD_DPADEAST = 17;
	public var RIGHTPAD_TOUCH = 18;
	public var RIGHTPAD_SWIPE = 19;
	public var RIGHTPAD_CLICK = 20;
	public var RIGHTPAD_DPADNORTH = 21;
	public var RIGHTPAD_DPADSOUTH = 22;
	public var RIGHTPAD_DPADWEST = 23;
	public var RIGHTPAD_DPADEAST = 24;
	public var LEFTTRIGGER_PULL = 25;
	public var LEFTTRIGGER_CLICK = 26;
	public var RIGHTTRIGGER_PULL = 27;
	public var RIGHTTRIGGER_CLICK = 28;
	public var LEFTSTICK_MOVE = 29;
	public var LEFTSTICK_CLICK = 30;
	public var LEFTSTICK_DPADNORTH = 31;
	public var LEFTSTICK_DPADSOUTH = 32;
	public var LEFTSTICK_DPADWEST = 33;
	public var LEFTSTICK_DPADEAST = 34;
	public var GRYRO_MOVE = 35;
	public var GRYRO_PITCH = 36;
	public var GRYRO_YAW = 37;
	public var GRYRO_ROLL = 38;
	public var COUNT = 39;
	
	@:from private static function fromString (s:String):EControllerActionOrigin{
		
		var i = Std.parseInt(s);
		
		if (i == null) {
			
			//if it's not a numeric value, try to interpret it from its name
			s = s.toUpperCase();
			return fromStringMap.exists(s) ? fromStringMap.get(s) : NONE;
		}
		
		return cast Std.int(i);
		
	}
	
	@:to public inline function toString():String
	{
		return toStringMap.get(cast this);
	}
	
}

@:enum abstract ESteamControllerPad(Int) {
	public var LEFT = 0;
	public var RIGHT = 1;
}

@:enum abstract EControllerSource(Int) {
	public var NONE = 0;
	public var LEFTTRACKPAD = 1;
	public var RIGHTTRACKPAD = 2;
	public var JOYSTICK = 3;
	public var ABXY = 4;
	public var SWITCH = 5;
	public var LEFTTRIGGER = 6;
	public var RIGHTTRIGGER = 7;
	public var GYRO = 8;
	public var COUNT = 9;
}

@:enum abstract EControllerSourceMode(Int) {
	public var NONE = 0;
	public var DPAD = 1;
	public var BUTTONS = 2;
	public var FOURBUTTONS = 3;
	public var ABSOLUTEMOUSE = 4;
	public var RELATIVEMOUSE = 5;
	public var JOYSTICKMOVE = 6;
	public var JOYSTICKCAMERA = 7;
	public var SCROLLWHEEL = 8;
	public var TRIGGER = 9;
	public var TOUCHMENU = 10;
	public var MOUSEJOYSTICK = 11;
	public var MOUSEREGION = 12;
}