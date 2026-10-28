class_name RollItem
extends VRPickable
## Petit ingrédient pour rouler : tête de weed (« bud », à mettre dans le grinder),
## pincée d'herbe moulue (« weed », sortie du grinder), pincée de tabac (« tobacco »,
## sortie du sachet de tabac à rouler) ou filtre (« filter », sorti de sa boîte). On le
## lâche sur ce qui le prend : grinder ouvert (tête), feuille à rouler (pincées, filtre)
## — voir RollingSheet et Grinder (try_receive).

@export_enum("bud", "weed", "filter", "tobacco") var kind := "bud"
## Pincée : quantité d'herbe / de tabac (1 = de quoi rouler un joint bien chargé).
@export var amount := 1.0
