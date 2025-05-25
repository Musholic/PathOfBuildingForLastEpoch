using System.Text.Json;
using System.Text.RegularExpressions;
using Il2Cpp;

// ReSharper disable NotAccessedField.Global
// ReSharper disable MemberCanBePrivate.Global
// ReSharper disable CollectionNeverQueried.Global

namespace PobfleExtractor
{
    public static class ItemBases
    {
        private static readonly string ItemBasesDir = Core.BaseSrcDir + @"\Data\Bases";

        public static void Extract()
        {
            var itemList = ItemList.instance;
            var itemBases = new Dictionary<string, ItemBase>();
            foreach (var baseEquipmentItem in itemList.EquippableItems)
            {
                foreach (var equipmentItem in baseEquipmentItem.subItems)
                {
                    var name = equipmentItem.name;
                    if (equipmentItem.displayName != "")
                    {
                        name = equipmentItem.displayName;
                    }

                    itemBases.Add(name, new ItemBase(baseEquipmentItem, equipmentItem));
                }
            }

            var json = JsonSerializer.Serialize(itemBases, Core.JsonSerializerOptions);

            var filePath = Path.Combine(ItemBasesDir, "bases.json");
            Core.Logger.Msg("Writing file: " + filePath);
            File.WriteAllText(filePath, json);
        }
    }

    public class ItemBase
    {
        public string Type;
        public int BaseTypeID;
        public int SubTypeID;
        public readonly Dictionary<string, int> Req = new();
        public float AffixEffectModifier;
        public readonly List<string> Implicits = [];
        public Dictionary<string, float> Weapon;

        public ItemBase(ItemList.BaseEquipmentItem baseEquipmentItem, ItemList.EquipmentItem equipmentItem)
        {
            Type = baseEquipmentItem.displayName;
            BaseTypeID = baseEquipmentItem.baseTypeID;
            SubTypeID = equipmentItem.subTypeID;
            Req.Add("level", equipmentItem.levelRequirement);
            AffixEffectModifier = baseEquipmentItem.affixEffectModifier;
            foreach (var itemImplicit in equipmentItem.implicits)
            {
                // ReSharper disable once CompareOfFloatsByEqualityOperator
                var isRange = itemImplicit.implicitValue != itemImplicit.implicitMaxValue;
                var format = ModFormatting.FormatProperty(itemImplicit.property, itemImplicit.tags,
                    itemImplicit.specialTag,
                    itemImplicit.type, itemImplicit.implicitValue, null, false, false, false, true, isRange,
                    itemImplicit.implicitMaxValue);
                format = Regex.Replace(format, @"(\d+)(%?) to (\d+)%?", "($1-$3)$2");
                Implicits.Add(format);
            }

            if (baseEquipmentItem.isWeapon)
            {
                Weapon = new Dictionary<string, float>
                {
                    { "AttackRateBase", equipmentItem.attackRate },
                    { "Range", 1 + equipmentItem.addedWeaponRange }
                };
            }
        }
    }
}