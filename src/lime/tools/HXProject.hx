package lime.tools;

import haxe.io.Eof;
import haxe.Json;
import haxe.Serializer;
import haxe.Unserializer;
import hxp.*;
import lime.tools.Architecture;
import lime.tools.AssetType;
import lime.tools.Platform;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#if (haxe_ver >= 4)
import haxe.xml.Access;
#else
import haxe.xml.Fast as Access;
#end
#if (lime && lime_cffi && !macro)
import lime.text.Font;

@:access(lime.text.Font)
#end
class HXProject extends Script
{
	public var app:ApplicationData;
	public var architectures:Array<Architecture>;
	public var assets:Array<Asset>;
	// public var command:String;
	public var config:ConfigData;
	public var debug:Bool;
	// public var defines:Map<String, Dynamic>;
	public var dependencies:Array<Dependency>;
	public var environment:Map<String, String>;
	public var haxedefs:Map<String, Dynamic>;
	public var haxeflags:Array<String>;
	public var haxelibs:Array<Haxelib>;
	public var host(get, null):Platform;
	public var icons:Array<Icon>;
	public var javaPaths:Array<String>;
	public var keystore:Keystore;
	public var languages:Array<String>;
	public var launchStoryboard:LaunchStoryboard;
	public var libraries:Array<Library>;
	public var libraryHandlers:Map<String, String>;
	public var meta:MetaData;
	public var modules:Map<String, ModuleData>;
	public var ndlls:Array<NDLL>;
	public var platformType:PlatformType;
	public var postBuildCallbacks:Array<CLICommand>;
	public var preBuildCallbacks:Array<CLICommand>;
	public var samplePaths:Array<String>;
	public var sources:Array<String>;
	public var splashScreens:Array<SplashScreen>;
	public var target:Platform;
	public var targetFlags:Map<String, String>;
	public var targetHandlers:Map<String, String>;
	public var templateContext(get, null):Dynamic;
	public var templatePaths:Array<String>;
	@:isVar public var window(get, set):WindowData;
	public var windows:Array<WindowData>;

	private var defaultApp:ApplicationData;
	private var defaultArchitectures:Array<Architecture>;
	private var defaultMeta:MetaData;
	private var defaultWindow:WindowData;
	private var needRerun:Bool;

	public static var _command:String;
	public static var _debug:Bool;
	public static var _environment:Map<String, String>;
	public static var _target:Platform;
	public static var _targetFlags:Map<String, String>;
	public static var _templatePaths:Array<String>;
	public static var _userDefines:Map<String, Dynamic>;
	private static var initialized:Bool;

	public static function main()
	{
		var args = Sys.args();

		if (args.length < 2)
		{
			return;
		}

		var inputData = Unserializer.run(File.getContent(args[0]));
		var outputFile = args[1];

		HXProject._command = inputData.command;
		HXProject._target = cast inputData.target;
		HXProject._debug = inputData.debug;
		HXProject._targetFlags = inputData.targetFlags;
		HXProject._templatePaths = inputData.templatePaths;
		HXProject._userDefines = inputData.userDefines;
		HXProject._environment = inputData.environment;
		Log.verbose = inputData.logVerbose;
		Log.enableColor = inputData.logEnableColor;

		#if lime
		System.dryRun = inputData.processDryRun;
		#end

		Haxelib.debug = inputData.haxelibDebug;

		initialize();

		var classRef = Type.resolveClass(inputData.name);
		var instance = Type.createInstance(classRef, []);

		var serializer = new Serializer();
		serializer.useCache = true;
		serializer.serialize(instance);

		File.saveContent(outputFile, serializer.toString());
	}

	public function new()
	{
		super();

		initialize();

		command = _command;
		config = new ConfigData();
		debug = _debug;
		target = _target;
		targetFlags = MapTools.copy(_targetFlags);
		templatePaths = _templatePaths.copy();

		defaultMeta =
			{
				title: "MyApplication",
				description: "",
				packageName: "com.example.myapp",
				version: "1.0.0",
				company: "",
				companyUrl: "",
				buildNumber: null,
				companyId: ""
			}
		defaultApp =
			{
				main: "Main",
				file: "MyApplication",
				path: "bin",
				preloader: "",
				swfVersion: 17,
				url: "",
				init: null
			}
		defaultWindow =
			{
				width: 800,
				height: 600,
				parameters: "{}",
				background: 0xFFFFFF,
				fps: 30,
				hardware: true,
				display: 0,
				resizable: true,
				borderless: false,
				orientation: Orientation.AUTO,
				vsync: false,
				fullscreen: false,
				allowHighDPI: true,
				alwaysOnTop: false,
				antialiasing: 0,
				allowShaders: true,
				requireShaders: false,
				depthBuffer: true,
				stencilBuffer: true,
				colorDepth: 32,
				failIfMajorPerformanceCaveat: false,
				maximized: false,
				minimized: false,
				hidden: false,
				title: ""
			}

		platformType = PlatformType.DESKTOP;
		architectures = [];

		switch (target)
		{
			case AIR:
				if (targetFlags.exists("ios") || targetFlags.exists("android"))
				{
					platformType = PlatformType.MOBILE;

					defaultWindow.width = 0;
					defaultWindow.height = 0;
				}
				else
				{
					platformType = PlatformType.DESKTOP;
				}

				architectures = [];

			case FLASH:
				platformType = PlatformType.WEB;
				architectures = [];

			case HTML5, FIREFOX:
				platformType = PlatformType.WEB;
				architectures = [];

				if (!targetFlags.exists("electron"))
				{
					defaultWindow.width = 0;
					defaultWindow.height = 0;
				}
				else
				{
					// platformType = PlatformType.DESKTOP;
				}

				defaultWindow.fps = 60;
				defaultWindow.allowHighDPI = false;

			case EMSCRIPTEN:
				platformType = PlatformType.WEB;
				architectures = [];

				defaultWindow.fps = 60;
				defaultWindow.allowHighDPI = false;

			case ANDROID, BLACKBERRY, IOS, TIZEN, WEBOS, TVOS:
				platformType = PlatformType.MOBILE;

				if (target == Platform.IOS)
				{
					architectures = [Architecture.ARMV7, Architecture.ARM64];
				}
				else if (target == Platform.ANDROID)
				{
					if (targetFlags.exists("simulator") || targetFlags.exists("emulator"))
					{
						architectures = [Architecture.X86];
					}
					else
					{
						architectures = [Architecture.ARMV7];
						if (target == ANDROID) architectures.push(Architecture.ARM64);
					}
				}
				else if (target == Platform.TVOS)
				{
					architectures = [Architecture.ARM64];
				}
				else
				{
					architectures = [Architecture.ARMV6];
				}

				defaultWindow.width = 0;
				defaultWindow.height = 0;
				defaultWindow.fullscreen = true;
				defaultWindow.requireShaders = true;

			case WINDOWS:
				platformType = PlatformType.DESKTOP;

				if (targetFlags.exists("uwp") || targetFlags.exists("winjs"))
				{
					architectures = [];

					targetFlags.set("uwp", "");
					targetFlags.set("winjs", "");

					defaultWindow.width = 0;
					defaultWindow.height = 0;
					defaultWindow.fps = 60;
				}
				else
				{
					switch (System.hostArchitecture)
					{
						case ARMV6: architectures = [ARMV6];
						case ARMV7: architectures = [ARMV7];
						case X86: architectures = [X86];
						case X64: architectures = [X64];
						default: architectures = [];
					}
				}

				defaultWindow.allowHighDPI = false;

			case MAC, LINUX:
				platformType = PlatformType.DESKTOP;
				switch (System.hostArchitecture)
				{
					case ARMV6: architectures = [ARMV6];
					case ARMV7: architectures = [ARMV7];
					case X86: architectures = [X86];
					case X64: architectures = [X64];
					default: architectures = [];
				}

				defaultWindow.allowHighDPI = false;

			default:
				// TODO: Better handling of platform type for pluggable targets

				platformType = PlatformType.CONSOLE;

				defaultWindow.width = 0;
				defaultWindow.height = 0;
				defaultWindow.fps = 60;
				defaultWindow.fullscreen = true;
		}

		defaultArchitectures = architectures.copy();

		meta = ObjectTools.copyFields(defaultMeta, {});
		app = ObjectTools.copyFields(defaultApp, {});
		window = ObjectTools.copyFields(defaultWindow, {});
		windows = [window];
		assets = new Array<Asset>();

		if (_userDefines != null)
		{
			defines = MapTools.copy(_userDefines);
		}
		else
		{
			defines = new Map<String, String>();
		}

		dependencies = new Array<Dependency>();

		if (_environment != null)
		{
			environment = _environment;
		}
		else
		{
			environment = Sys.environment();
		}

		haxedefs = new Map<String, Dynamic>();
		haxeflags = new Array<String>();
		haxelibs = new Array<Haxelib>();
		icons = new Array<Icon>();
		javaPaths = new Array<String>();
		languages = new Array<String>();
		libraries = new Array<Library>();
		libraryHandlers = new Map<String, String>();
		modules = new Map<String, ModuleData>();
		ndlls = new Array<NDLL>();
		postBuildCallbacks = new Array<CLICommand>();
		preBuildCallbacks = new Array<CLICommand>();
		sources = new Array<String>();
		samplePaths = new Array<String>();
		splashScreens = new Array<SplashScreen>();
		targetHandlers = new Map<String, String>();
	}

	public function clone():HXProject
	{
		var project = new HXProject();

		ObjectTools.copyFields(app, project.app);
		project.architectures = architectures.copy();
		project.assets = assets.copy();

		for (i in 0...assets.length)
		{
			project.assets[i] = assets[i].clone();
		}

		project.command = command;
		project.config = config.clone();
		project.debug = debug;

		for (key in defines.keys())
		{
			project.defines.set(key, defines.get(key));
		}

		for (dependency in dependencies)
		{
			project.dependencies.push(dependency.clone());
		}

		for (key in environment.keys())
		{
			project.environment.set(key, environment.get(key));
		}

		for (key in haxedefs.keys())
		{
			project.haxedefs.set(key, haxedefs.get(key));
		}

		project.haxeflags = haxeflags.copy();

		for (haxelib in haxelibs)
		{
			project.haxelibs.push(haxelib.clone());
		}

		for (icon in icons)
		{
			project.icons.push(icon.clone());
		}

		project.javaPaths = javaPaths.copy();

		if (keystore != null)
		{
			project.keystore = keystore.clone();
		}

		project.languages = languages.copy();

		if (launchStoryboard != null)
		{
			project.launchStoryboard = launchStoryboard.clone();
		}

		for (library in libraries)
		{
			project.libraries.push(library.clone());
		}

		for (key in libraryHandlers.keys())
		{
			project.libraryHandlers.set(key, libraryHandlers.get(key));
		}

		ObjectTools.copyFields(meta, project.meta);

		for (key in modules.keys())
		{
			project.modules.set(key, modules.get(key).clone());
		}

		for (ndll in ndlls)
		{
			project.ndlls.push(ndll.clone());
		}

		project.platformType = platformType;
		project.postBuildCallbacks = postBuildCallbacks.copy();
		project.preBuildCallbacks = preBuildCallbacks.copy();
		project.samplePaths = samplePaths.copy();
		project.sources = sources.copy();

		for (splashScreen in splashScreens)
		{
			project.splashScreens.push(splashScreen.clone());
		}

		project.target = target;

		for (key in targetFlags.keys())
		{
			project.targetFlags.set(key, targetFlags.get(key));
		}

		for (key in targetHandlers.keys())
		{
			project.targetHandlers.set(key, targetHandlers.get(key));
		}

		project.templatePaths = templatePaths.copy();

		for (i in 0...windows.length)
		{
			project.windows[i] = (ObjectTools.copyFields(windows[i], {}));
		}

		return project;
	}

	private function filter(text:String, include:Array<String> = null, exclude:Array<String> = null):Bool
	{
		if (include == null)
		{
			include = ["*"];
		}

		if (exclude == null)
		{
			exclude = [];
		}

		for (filter in exclude)
		{
			if (filter != "")
			{
				filter = StringTools.replace(filter, ".", "\\.");
				filter = StringTools.replace(filter, "*", ".*");

				var regexp = new EReg("^" + filter + "$", "i");

				if (regexp.match(text))
				{
					return false;
				}
			}
		}

		for (filter in include)
		{
			if (filter != "")
			{
				filter = StringTools.replace(filter, ".", "\\.");
				filter = StringTools.replace(filter, "*", ".*");

				var regexp = new EReg("^" + filter, "i");

				if (regexp.match(text))
				{
					return true;
				}
			}
		}

		return false;
	}

	public static function fromFile(projectFile:String, userDefines:Map<String, Dynamic> = null, includePaths:Array<String> = null):HXProject
	{
		var project:HXProject = null;

		var path = FileSystem.fullPath(Path.withoutDirectory(projectFile));
		var name = Path.withoutDirectory(Path.withoutExtension(projectFile));
		name = name.substr(0, 1).toUpperCase() + name.substr(1);

		var tempDirectory = System.getTemporaryDirectory();
		var classFile = Path.combine(tempDirectory, name + ".hx");
		var nekoOutput = Path.combine(tempDirectory, name + ".n");

		System.copyFile(path, classFile);

		#if lime
		var args = [
			name, "-main", "lime.tools.HXProject", "-cp", tempDirectory, "-neko", nekoOutput, "-cp", Path.combine(Haxelib.getPath(new Haxelib("hxp")), "src"),
			"-lib", "lime", "-lib", "hxp"
		];
		#else
		var args = [
			name,
			"--interp",
			"-main",
			"lime.tools.HXProject",
			"-cp",
			tempDirectory,
			"-cp",
			Path.combine(Haxelib.getPath(new Haxelib("hxp")), "src")
		];
		#end
		var input = File.read(classFile, false);
		var tag = "@:compiler(";

		try
		{
			while (true)
			{
				var line = input.readLine();

				if (StringTools.startsWith(line, tag))
				{
					args.push(line.substring(tag.length + 1, line.length - 2));
				}
			}
		}
		catch (ex:Eof) {}

		input.close();

		var cacheDryRun = System.dryRun;
		System.dryRun = false;

		#if lime
		System.runCommand("", "haxe", args);
		#end

		var inputFile = Path.combine(tempDirectory, "input.dat");
		var outputFile = Path.combine(tempDirectory, "output.dat");

		var inputData = Serializer.run(
			{
				command: HXProject._command,
				name: name,
				target: HXProject._target,
				debug: HXProject._debug,
				targetFlags: HXProject._targetFlags,
				templatePaths: HXProject._templatePaths,
				userDefines: HXProject._userDefines,
				environment: HXProject._environment,
				logVerbose: Log.verbose,
				logEnableColor: Log.enableColor,
				processDryRun: cacheDryRun,
				haxelibDebug: Haxelib.debug
			});

		File.saveContent(inputFile, inputData);

		try
		{
			#if lime
			System.runCommand("", "neko", [FileSystem.fullPath(nekoOutput), inputFile, outputFile]);
			#else
			System.runCommand("", "haxe", args.concat(["--", inputFile, outputFile]));
			#end
		}
		catch (e:Dynamic)
		{
			FileSystem.deleteFile(inputFile);
			Sys.exit(1);
		}

		System.dryRun = cacheDryRun;

		var tPaths:Array<String> = [];

		try
		{
			FileSystem.deleteFile(inputFile);

			var outputPath = Path.combine(tempDirectory, "output.dat");

			if (FileSystem.exists(outputPath))
			{
				var output = File.getContent(outputPath);
				var unserializer = new Unserializer(output);
				unserializer.setResolver(cast {resolveEnum: Type.resolveEnum, resolveClass: resolveClass});
				project = unserializer.unserialize();

				// Because the project file template paths need to take priority,
				// Add them after loading template paths from haxelibs below
				tPaths = project.templatePaths;
				project.templatePaths = [];

				FileSystem.deleteFile(outputPath);
			}
		}
		catch (e:Dynamic) {}

		System.removeDirectory(tempDirectory);

		if (project != null)
		{
			for (key in project.environment.keys())
			{
				Sys.putEnv(key, project.environment[key]);
			}

			var defines = MapTools.copyDynamic(userDefines);
			MapTools.copyKeys(project.defines, defines);

			processHaxelibs(project, defines);

			// Adding template paths from the Project file
			project.templatePaths = ArrayTools.concatUnique(project.templatePaths, tPaths, true);
		}

		return project;
	}

	public static function fromHaxelib(haxelib:Haxelib, userDefines:Map<String, Dynamic> = null, clearCache:Bool = false):HXProject
	{
		if (haxelib.name == null || haxelib.name == "")
		{
			return null;
		}

		var path = Haxelib.getPath(haxelib, false, clearCache);

		if (path == null || path == "")
		{
			return null;
		}

		// if (!userDefines.exists (haxelib.name)) {
		//
		// userDefines.set (haxelib.name, Haxelib.getVersion (haxelib));
		//
		// }

		return HXProject.fromPath(path, userDefines);
	}

	public static function fromPath(path:String, userDefines:Map<String, Dynamic> = null):HXProject
	{
		if (!FileSystem.exists(path) || !FileSystem.isDirectory(path))
		{
			return null;
		}

		var files = ["include.lime", "include.nmml", "include.xml"];
		var projectFile = null;

		for (file in files)
		{
			if (projectFile == null && FileSystem.exists(Path.combine(path, file)))
			{
				projectFile = Path.combine(path, file);
			}
		}

		if (projectFile != null)
		{
			var project = new ProjectXMLParser(projectFile, userDefines);

			if (project.config.get("project.rebuild.path") == null)
			{
				project.config.set("project.rebuild.path", Path.combine(path, "project"));
			}

			return project;
		}

		return null;
	}

	private function getHaxelibVersion(haxelib:Haxelib):String
	{
		var version = haxelib.version;

		if (version == "" || version == null)
		{
			var haxelibPath = Haxelib.getPath(haxelib);
			var jsonPath = Path.combine(haxelibPath, "haxelib.json");

			try
			{
				if (FileSystem.exists(jsonPath))
				{
					var json = Json.parse(File.getContent(jsonPath));
					version = json.version;
				}
			}
			catch (e:Dynamic) {}
		}

		return version;
	}

	public function include(path:String):Void
	{
		// extend project file somehow?
	}

	public function includeAssets(path:String, rename:String = null, include:Array<String> = null, exclude:Array<String> = null):Void
	{
		if (include == null)
		{
			include = ["*"];
		}

		if (exclude == null)
		{
			exclude = [];
		}

		exclude = exclude.concat([".*", "cvs", "thumbs.db", "desktop.ini", "*.hash"]);

		if (path == "")
		{
			return;
		}

		var targetPath = "";

		if (rename != null)
		{
			targetPath = rename;
		}
		else
		{
			targetPath = path;
		}

		if (!FileSystem.exists(path))
		{
			Log.error("Could not find asset path \"" + path + "\"");
			return;
		}

		var files = FileSystem.readDirectory(path);

		if (targetPath != "")
		{
			targetPath += "/";
		}

		for (file in files)
		{
			if (FileSystem.isDirectory(path + "/" + file))
			{
				if (filter(file, ["*"], exclude))
				{
					includeAssets(path + "/" + file, targetPath + file, include, exclude);
				}
			}
			else
			{
				if (filter(file, include, exclude))
				{
					assets.push(new Asset(path + "/" + file, targetPath + file));
				}
			}
		}
	}

	// #if lime
	public function includeXML(xml:String):Void
	{
		var projectXML = new ProjectXMLParser();
		@:privateAccess projectXML.parseXML(new Access(Xml.parse(xml).firstElement()), "");
		merge(projectXML);
	}

	// #end
	private static function initialize():Void
	{
		if (!initialized)
		{
			if (_target == null)
			{
				_target = cast System.hostPlatform;
			}

			if (_targetFlags == null)
			{
				_targetFlags = new Map<String, String>();
			}

			if (_templatePaths == null)
			{
				_templatePaths = new Array<String>();
			}

			initialized = true;
		}
	}

	public function merge(project:HXProject):Void
	{
		if (project != null)
		{
			ObjectTools.copyUniqueFields(project.meta, meta, project.defaultMeta);
			ObjectTools.copyUniqueFields(project.app, app, project.defaultApp);

			for (i in 0...project.windows.length)
			{
				if (i < windows.length)
				{
					ObjectTools.copyUniqueFields(project.windows[i], windows[i], project.defaultWindow);
				}
				else
				{
					windows.push(ObjectTools.copyFields(project.windows[i], {}));
				}
			}

			MapTools.copyUniqueKeys(project.defines, defines);
			MapTools.copyUniqueKeys(project.environment, environment);
			MapTools.copyUniqueKeysDynamic(project.haxedefs, haxedefs);
			MapTools.copyUniqueKeys(project.libraryHandlers, libraryHandlers);
			MapTools.copyUniqueKeys(project.targetHandlers, targetHandlers);

			config.merge(project.config);

			for (architecture in project.architectures)
			{
				if (defaultArchitectures.indexOf(architecture) == -1)
				{
					architectures.push(architecture);
				}
			}

			if (project.architectures.length > 0)
			{
				for (architecture in defaultArchitectures)
				{
					if (project.architectures.indexOf(architecture) == -1)
					{
						architectures.remove(architecture);
					}
				}
			}

			assets = ArrayTools.concatUnique(assets, project.assets);
			dependencies = ArrayTools.concatUnique(dependencies, project.dependencies, true);
			haxeflags = ArrayTools.concatUnique(haxeflags, project.haxeflags);
			haxelibs = ArrayTools.concatUnique(haxelibs, project.haxelibs, true, "name");
			icons = ArrayTools.concatUnique(icons, project.icons);
			javaPaths = ArrayTools.concatUnique(javaPaths, project.javaPaths, true);

			if (keystore == null)
			{
				keystore = project.keystore;
			}
			else
			{
				keystore.merge(project.keystore);
			}

			if (launchStoryboard == null)
			{
				launchStoryboard = project.launchStoryboard;
			}
			else
			{
				launchStoryboard.merge(project.launchStoryboard);
			}

			languages = ArrayTools.concatUnique(languages, project.languages, true);
			libraries = ArrayTools.concatUnique(libraries, project.libraries, true);

			for (key in project.modules.keys())
			{
				if (modules.exists(key))
				{
					modules.get(key).merge(project.modules.get(key));
				}
				else
				{
					modules.set(key, project.modules.get(key));
				}
			}

			ndlls = ArrayTools.concatUnique(ndlls, project.ndlls);
			postBuildCallbacks = postBuildCallbacks.concat(project.postBuildCallbacks);
			preBuildCallbacks = preBuildCallbacks.concat(project.preBuildCallbacks);
			samplePaths = ArrayTools.concatUnique(samplePaths, project.samplePaths, true);
			sources = ArrayTools.concatUnique(sources, project.sources, true);
			splashScreens = ArrayTools.concatUnique(splashScreens, project.splashScreens);
			templatePaths = ArrayTools.concatUnique(templatePaths, project.templatePaths, true);
		}
	}

	public function path(value:String):Void
	{
		if (host == Platform.WINDOWS)
		{
			setenv("PATH", value + ";" + Sys.getEnv("PATH"));
		}
		else
		{
			setenv("PATH", value + ":" + Sys.getEnv("PATH"));
		}
	}

	// #if lime
	@:noCompletion private static function processHaxelibs(project:HXProject, userDefines:Map<String, Dynamic>):Void
	{
		var haxelibs = project.haxelibs.copy();
		project.haxelibs = [];

		for (haxelib in haxelibs)
		{
			var validatePath = Haxelib.getPath(haxelib, true);
			project.haxelibs.push(haxelib);

			var includeProject = HXProject.fromHaxelib(haxelib, userDefines);

			if (includeProject != null)
			{
				for (ndll in includeProject.ndlls)
				{
					if (ndll.haxelib == null)
					{
						ndll.haxelib = haxelib;
					}
				}

				project.merge(includeProject);
			}
		}
	}

	@:noCompletion private static function resolveClass(name:String):Class<Dynamic>
	{
		var type = Type.resolveClass(name);

		if (type == null)
		{
			return HXProject;
		}
		else
		{
			return type;
		}
	}

	// #end
	public function setenv(name:String, value:String):Void
	{
		if (value == null)
		{
			environment.remove(name);
			value = "";
		}

		if (name == "HAXELIB_PATH")
		{
			var currentPath = Haxelib.getRepositoryPath();
			Sys.putEnv(name, value);
			var newPath = Haxelib.getRepositoryPath(true);

			if (currentPath != newPath)
			{
				var valid = try
				{
					(newPath != null && newPath != "" && FileSystem.exists(FileSystem.fullPath(newPath)));
				}
				catch (e:Dynamic)
				{
					false;
				}

				if (!valid)
				{
					Log.error("The specified haxelib repository path \"" + value + "\" does not exist");
				}
				else
				{
					needRerun = true;
				}
			}
		}
		else
		{
			Sys.putEnv(name, value);
		}

		if (value != "")
		{
			environment.set(name, value);
		}
	}

	// Getters & Setters
	private function get_host():Platform
	{
		return cast System.hostPlatform;
	}

	private function get_templateContext():Dynamic
	{
		var context:Dynamic = {};

		if (app == null) app = {};
		if (meta == null) meta = {};

		if (window == null)
		{
			window = {};
			windows = [window];
		}

		ObjectTools.copyMissingFields(defaultApp, app);
		ObjectTools.copyMissingFields(defaultMeta, meta);

		for (item in windows)
		{
			ObjectTools.copyMissingFields(defaultWindow, item);
		}

		// config.populate ();

		for (field in Reflect.fields(app))
		{
			Reflect.setField(context, "APP_" + StringTools.formatUppercaseVariable(field), Reflect.field(app, field));
		}

		context.BUILD_DIR = app.path;

		for (key in environment.keys())
		{
			Reflect.setField(context, "ENV_" + key, environment.get(key));
		}

		context.meta = meta;

		for (field in Reflect.fields(meta))
		{
			Reflect.setField(context, "APP_" + StringTools.formatUppercaseVariable(field), Reflect.field(meta, field));
			Reflect.setField(context, "META_" + StringTools.formatUppercaseVariable(field), Reflect.field(meta, field));
		}

		context.APP_PACKAGE = context.META_PACKAGE = meta.packageName;

		for (field in Reflect.fields(windows[0]))
		{
			Reflect.setField(context, "WIN_" + StringTools.formatUppercaseVariable(field), Reflect.field(windows[0], field));
			Reflect.setField(context, "WINDOW_" + StringTools.formatUppercaseVariable(field), Reflect.field(windows[0], field));
		}

		if (windows[0].orientation == Orientation.LANDSCAPE || windows[0].orientation == Orientation.PORTRAIT)
		{
			context.WIN_ORIENTATION = Std.string(windows[0].orientation).toLowerCase();
			context.WINDOW_ORIENTATION = Std.string(windows[0].orientation).toLowerCase();
		}
		else
		{
			context.WIN_ORIENTATION = "auto";
			context.WINDOW_ORIENTATION = "auto";
		}

		context.windows = windows;

		for (i in 0...windows.length)
		{
			for (field in Reflect.fields(windows[i]))
			{
				Reflect.setField(context, "WINDOW_" + StringTools.formatUppercaseVariable(field) + "_" + i, Reflect.field(windows[i], field));
			}

			if (windows[i].orientation == Orientation.LANDSCAPE || windows[i].orientation == Orientation.PORTRAIT)
			{
				Reflect.setField(context, "WINDOW_ORIENTATION_" + i, Std.string(windows[i].orientation).toLowerCase());
			}
			else
			{
				Reflect.setField(context, "WINDOW_ORIENTATION_" + i, "");
			}

			if (windows[i].title == "") windows[i].title = meta.title;
		}

		for (haxeflag in haxeflags)
		{
			if (StringTools.startsWith(haxeflag, "-lib"))
			{
				Reflect.setField(context, "LIB_" + StringTools.formatUppercaseVariable(haxeflag.substr(5)), "true");
			}
		}

		context.assets = new Array<Dynamic>();

		for (asset in assets)
		{
			if (asset.type != AssetType.TEMPLATE)
			{
				var embeddedAsset:Dynamic = {};
				ObjectTools.copyFields(asset, embeddedAsset);

				embeddedAsset.sourcePath = Path.standardize(asset.sourcePath);

				if (asset.embed == null)
				{
					embeddedAsset.embed = (platformType == PlatformType.WEB || target == AIR);
				}

				embeddedAsset.type = Std.string(asset.type).toLowerCase();

				#if (lime && lime_cffi && !macro)
				if (asset.type == FONT)
				{
					try
					{
						var font = Font.fromFile(asset.sourcePath);
						embeddedAsset.fontName = font.name;

						Log.info("", " - \x1b[1mDetecting font name:\x1b[0m " + asset.sourcePath + " \x1b[3;37m->\x1b[0m \"" + font.name + "\"");
					}
					catch (e:Dynamic) {}
				}
				#end

				context.assets.push(embeddedAsset);
			}
		}

		context.languages = (languages.length > 0) ? languages : null;
		context.libraries = new Array<Dynamic>();
		var embeddedLibraries = new Map<String, Dynamic>();

		for (library in libraries)
		{
			var embeddedLibrary:Dynamic = {};
			ObjectTools.copyFields(library, embeddedLibrary);
			context.libraries.push(embeddedLibrary);
			embeddedLibraries[library.name] = embeddedLibrary;
		}

		for (asset in assets)
		{
			if (asset.library != null && !embeddedLibraries.exists(asset.library))
			{
				var embeddedLibrary:Dynamic = {};
				embeddedLibrary.name = asset.library;
				context.libraries.push(embeddedLibrary);
				embeddedLibraries[asset.library] = embeddedLibrary;
			}
		}

		context.ndlls = new Array<Dynamic>();

		for (ndll in ndlls)
		{
			var templateNDLL:Dynamic = {};
			ObjectTools.copyFields(ndll, templateNDLL);
			templateNDLL.nameSafe = StringTools.replace(ndll.name, "-", "_");
			context.ndlls.push(templateNDLL);
		}

		// Reflect.setField (context, "ndlls", ndlls);
		// Reflect.setField (context, "sslCaCert", sslCaCert);
		context.sslCaCert = "";

		var compilerFlags = [];

		for (haxelib in haxelibs)
		{
			var name = haxelib.name;

			// TODO: Handle real version when better/smarter haxelib available
			var version = haxelib.version;
			// var version = Haxelib.getVersion (haxelib);

			if (version != null && version != "")
			{
				name += ":" + version;
			}

			// #if lime

			if (Haxelib.pathOverrides.exists(name))
			{
				var path = Haxelib.pathOverrides.get(name);
				var jsonPath = Path.combine(path, "haxelib.json");
				var added = false;

				try
				{
					if (FileSystem.exists(jsonPath))
					{
						var json = Json.parse(File.getContent(jsonPath));
						if (Reflect.hasField(json, "classPath"))
						{
							path = Path.combine(path, json.classPath);
						}

						var haxelibName = json.name;
						compilerFlags = ArrayTools.concatUnique(compilerFlags, ["-D " + haxelibName + "=" + json.version], true);
					}
				}
				catch (e:Dynamic) {}

				var param = "-cp " + path;
				compilerFlags.remove(param);
				compilerFlags.push(param);
			}
			else
			{
				var cache = Log.verbose;
				Log.verbose = Haxelib.debug;
				var output = "";

				try
				{
					output = Haxelib.runProcess("", ["path", name], true, true, true);
				}
				catch (e:Dynamic) {}

				Log.verbose = cache;

				var split = output.split("\n");
				var haxelibName = null;

				for (arg in split)
				{
					arg = StringTools.trim(arg);

					if (arg != "")
					{
						if (StringTools.startsWith(arg, "Error: "))
						{
							Log.error(arg.substr(7));
						}
						else if (!StringTools.startsWith(arg, "-"))
						{
							var path = Path.standardize(arg);

							if (path != null && StringTools.trim(path) != "" && !StringTools.startsWith(StringTools.trim(path), "#"))
							{
								var param = "-cp " + path;
								compilerFlags.remove(param);
								compilerFlags.push(param);
							}

							var version = "0.0.0";
							var jsonPath = Path.combine(path, "haxelib.json");

							try
							{
								if (FileSystem.exists(jsonPath))
								{
									var json = Json.parse(File.getContent(jsonPath));
									haxelibName = json.name;
									compilerFlags = ArrayTools.concatUnique(compilerFlags, ["-D " + haxelibName + "=" + json.version], true);
								}
							}
							catch (e:Dynamic) {}
						}
						else
						{
							if (StringTools.startsWith(arg, "-D ") && arg.indexOf("=") == -1)
							{
								var name = arg.substr(3);

								if (name != haxelibName)
								{
									compilerFlags = ArrayTools.concatUnique(compilerFlags, ["-D " + name], true);
								}

								/*var haxelib = new Haxelib (arg.substr (3));
									var path = Haxelib.getPath (haxelib);
									var version = getHaxelibVersion (haxelib);

									if (path != null) {

										CompatibilityHelper.patchProject (this, haxelib, version);
										compilerFlags = ArrayTools.concatUnique (compilerFlags, [ "-D " + haxelib.name + "=" + version ], true);

								}*/
							}
							else if (!StringTools.startsWith(arg, "-L"))
							{
								compilerFlags = ArrayTools.concatUnique(compilerFlags, [arg], true);
							}
						}
					}
				}
			}

			// #else

			// compilerFlags.push ("-lib " + name);

			// #end

			Reflect.setField(context, "LIB_" + StringTools.formatUppercaseVariable(haxelib.name), true);

			if (name == "nme")
			{
				context.EMBED_ASSETS = false;
			}
		}

		for (source in sources)
		{
			if (source != null && StringTools.trim(source) != "")
			{
				compilerFlags.push("-cp " + source);
			}
		}

		for (key in defines.keys())
		{
			var value = defines.get(key);

			if (value == null || value == "")
			{
				Reflect.setField(context, "SET_" + StringTools.formatUppercaseVariable(key), true);
			}
			else
			{
				Reflect.setField(context, "SET_" + StringTools.formatUppercaseVariable(key), value);
			}
		}

		for (key in haxedefs.keys())
		{
			var value = haxedefs.get(key);

			if (value == null || value == "")
			{
				compilerFlags.push("-D " + key);

				Reflect.setField(context, "DEFINE_" + StringTools.formatUppercaseVariable(key), true);
			}
			else
			{
				compilerFlags.push("-D " + key + "=" + value);

				Reflect.setField(context, "DEFINE_" + StringTools.formatUppercaseVariable(key), value);
			}
		}

		if (target != Platform.FLASH)
		{
			compilerFlags.push("-D " + Std.string(target).toLowerCase());
		}

		compilerFlags.push("-D " + Std.string(platformType).toLowerCase());
		compilerFlags = compilerFlags.concat(haxeflags);

		if (compilerFlags.length == 0)
		{
			context.HAXE_FLAGS = "";
		}
		else
		{
			context.HAXE_FLAGS = "\n" + compilerFlags.join("\n");
		}

		var main = app.main;

		if (main == null)
		{
			main = defaultApp.main;
		}

		var indexOfPeriod = main.lastIndexOf(".");

		context.APP_MAIN_PACKAGE = main.substr(0, indexOfPeriod + 1);
		context.APP_MAIN_CLASS = main.substr(indexOfPeriod + 1);

		var type = "release";

		if (debug)
		{
			type = "debug";
		}
		else if (targetFlags.exists("final"))
		{
			type = "final";
		}

		var hxml = Std.string(target).toLowerCase() + "/hxml/" + type + ".hxml";

		for (templatePath in templatePaths)
		{
			var path = Path.combine(templatePath, hxml);

			if (FileSystem.exists(path))
			{
				context.HXML_PATH = path;
			}
		}

		context.RELEASE = (type == "release");
		context.DEBUG = debug;
		context.FINAL = (type == "final");
		context.SWF_VERSION = app.swfVersion;
		context.PRELOADER_NAME = app.preloader;

		if (keystore != null)
		{
			context.KEY_STORE = Path.tryFullPath(keystore.path);

			if (keystore.password != null)
			{
				context.KEY_STORE_PASSWORD = keystore.password;
			}

			if (keystore.alias != null)
			{
				context.KEY_STORE_ALIAS = keystore.alias;
			}
			else if (keystore.path != null)
			{
				context.KEY_STORE_ALIAS = Path.withoutExtension(Path.withoutDirectory(keystore.path));
			}

			if (keystore.aliasPassword != null)
			{
				context.KEY_STORE_ALIAS_PASSWORD = keystore.aliasPassword;
			}
			else if (keystore.password != null)
			{
				context.KEY_STORE_ALIAS_PASSWORD = keystore.password;
			}
		}

		context.config = config;

		return context;
	}

	private function get_window():WindowData
	{
		if (windows != null)
		{
			return windows[0];
		}
		else
		{
			return window;
		}
	}

	private function set_window(value:WindowData):WindowData
	{
		if (windows != null)
		{
			return windows[0] = window = value;
		}
		else
		{
			return window = value;
		}
	}
}
