extends Resource
class_name EtapeFabrication

enum TypeEtape {
	CHAUFFE,
	FONTE,
	MOULAGE,
	MARTELAGE
}

@export var type_etape: TypeEtape = TypeEtape.CHAUFFE
