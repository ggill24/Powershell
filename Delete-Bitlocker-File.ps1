$assemblies=(
	"System",
    "System.IO",
    "System.Text.RegularExpressions",
    "System.IO",
    "System.Linq"
)

$source=@"

using System;
using System.Text.RegularExpressions;
using System.IO;
using System.Linq;

namespace DeleteBitlockerFile
{
	public static class Delete{
		public static void Main(){
			Regex rx = new Regex(@"[A-Za-z]+-[0-9]*-[\s\S]+", RegexOptions.Compiled | RegexOptions.IgnoreCase);
            var files = Directory.GetFiles(@"C:\\", "*.txt").Where(path => rx.IsMatch(path)).ToArray();
            if(files.Length == 0) { return; }

            foreach(var f in files)
            {
                File.Delete(f);
            }
		}
	}
}
"@

Add-Type -ReferencedAssemblies $assemblies -TypeDefinition $source -Language CSharp
[DeleteBitlockerFile.Delete]::Main()
