using MelonLoader;
using Il2Cpp;

[assembly: MelonInfo(typeof(PobfleExtractor.Core), "PobfleExtractor", "1.0.0", "Musholic", null)]
[assembly: MelonGame("Eleventh Hour Games", "Last Epoch")]
namespace PobfleExtractor
{
    public class Core : MelonMod
    {
        private static int genId = 0;

        public override void OnInitializeMelon()
        {
            LoggerInstance.Msg("Initialized.");
        }

        public override void OnUpdate()
        {
            // Use a hot reloadable variable to allow multiple extracts per debugging session
            int targetId = 1;
            if(genId != targetId && IsReady())
            {
                LoggerInstance.Msg("Starting extract...");
                genId = targetId;
                Extractor.ExtractAll();
            }
        }

        private bool IsReady()
        {
            // Wait for the resources to be available thanks to UnityExplorer doing its magic
            var trees = UnityEngine.Resources.FindObjectsOfTypeAll<CharacterTree>();
            LoggerInstance.Msg("Got tree count: " + trees.Length);

            return trees.Length > 0;
        }
    }
}