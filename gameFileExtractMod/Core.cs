using Il2Cpp;
using MelonLoader;
using PobfleExtractor;
using UnityEngine;

[assembly: MelonInfo(typeof(Core), "PobfleExtractor", "1.0.0", "Musholic", null)]
[assembly: MelonGame("Eleventh Hour Games", "Last Epoch")]

namespace PobfleExtractor
{
    public class Core : MelonMod
    {
        public static MelonLogger.Instance Logger;
        public static readonly UpperCaseFirstNaturalComparer StringComparer = new();

        private static int _genId;

        public override void OnInitializeMelon()
        {
            Logger = LoggerInstance;
            Logger.Msg("Initialized.");
        }

        public override void OnUpdate()
        {
            // Use a hot reloadable variable to allow multiple extracts per debugging session
            var targetId = 1;
            if (_genId != targetId && IsReady())
            {
                Logger.Msg("Starting extract...");
                _genId = targetId;
                TreeData.Extract();
                Application.Quit();
            }
        }

        private static bool IsReady()
        {
            // Wait for the resources to be available
            var trees = Resources.FindObjectsOfTypeAll<CharacterTree>();
            Logger.Msg("Got tree count: " + trees.Length);

            return trees.Length > 0;
        }
    }
}