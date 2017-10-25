import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
using StringTools;

class Run {
	static function error(msg)
	{
		Sys.println(msg);
		Sys.exit(1);
	}

	static function getPath(lib)
	{
		var p = new sys.io.Process("haxelib", ["path", lib]);
		var e = p.exitCode();
		var err = try p.stderr.readAll().toString().trim() catch (eof:haxe.io.Eof) "";
		var out = try p.stdout.readAll().toString().trim() catch (eof:haxe.io.Eof) "";
		if (e != 0) error('$err$out');
		var lines = out.split("\n");
		for (li in lines) {
			if (li.startsWith("-L "))
				return li.substr(3);
		}
		return null;
	}

	static function exportNdlls(lib, target, out)
	{
		var path = getPath(lib);
		if (path == null || !FileSystem.exists(path) || !FileSystem.isDirectory(path)) {
			Sys.println('$lib: no ndll directory, skipping');
			return false;
		}
		var tpath = Path.join([path, target]);
		if (!FileSystem.exists(tpath) || !FileSystem.isDirectory(tpath)) {
			Sys.println('$lib: no $target target directory, skipping');
			return false;
		}
		var something = false;
		for (ndll in FileSystem.readDirectory(tpath)) {
			if (!ndll.endsWith(".ndll")) continue;
			something = true;
			var src = Path.join([tpath, ndll]);
			var dest = Path.join([out, ndll]);
			Sys.println('Copying $ndll');
			File.saveBytes(dest, File.getBytes(src));
		}
		return something;
	}

	public static function main()
	{
		var target = null, out = null, libs = [];
		var args = Sys.args().copy();
		Sys.setCwd(args.pop());  // called from path
		while (args.length > 0) {
			switch args.shift() {
			case "-o", "--out":
				if (out != null) error("Please don't supply duplicate -o,--out options");
				if (args.length == 0) error("Missing argument to -o,--out: output path");
				out = args.shift();
			case opt if (opt.substr(0, 1) == "-"):
				if (Lambda.has(["-Linux64", "-Linux", "-Windows", "-Mac", "-BSD"], opt) && target == null) {
					target = opt.substr(1);
				} else {
					error("Don't know what to do with option " + opt);
				}
			case repeated if (Lambda.has(libs, repeated)):
				// ignore
			case library:
				libs.push(library);
			}
		}
		if (out == null)
			out = "./";
		if (target == null) {
			target = Sys.systemName();
			if (target == "Linux")
				target += ((neko.Lib.load("std", "sys_is64", 0)():Bool) ? "64" : "");
		}
		Sys.println('Using target $target');
		if (libs.length == 0) error("No library specified");
		var something = false;
		for (lib in libs)
			something = exportNdlls(lib, target, out) || something;
		Sys.exit(something ? 0 : 1);
	}
}

