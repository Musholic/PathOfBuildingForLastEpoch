using Il2Cpp;
using MelonLoader;
using UnityEngine;

[assembly: MelonInfo(typeof(MelonLoaderMod1.Core), "MelonLoaderMod1", "0.1.0", "Musholic", null)]
[assembly: MelonGame("Eleventh Hour Games", "Last Epoch")]

namespace MelonLoaderMod1
{
    public class Core : MelonMod
    {
        public override void OnInitializeMelon()
        {
            LoggerInstance.Msg("Initialized.");
            int count = GlobalTreeData.get().passiveTrees.Count;
            LoggerInstance.Msg("Got count: " + count);

            Application.Quit();
        }
        public override void OnUpdate()
        {
            LoggerInstance.Msg("OnUpdate!");
        }
    }
}