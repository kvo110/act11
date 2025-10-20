class CardModel {
    final int? id; // auto id
    final String name; 
    final String suit; 
    final String imageUrl;
    final int? folderId; // null if its in the deck and not yet placed

    CardModel({
        this.id,
        required this.name,
        required this.suit,
        required this.imageUrl,
        this.folderId,
    });

    Map<String, dynamic> toMap() {
        return {
            'id': id,
            'name': name,
            'suit': suit,
            'imageUrl': iamgeUrl,
            'folderId': folderId,
        };
    }

    factory CardModel.frontMap(Map<String, dynamic> map) {
        return CardModel(
            id: map['id'] as int?
            name: map['name'] as String,
            suit: map['suit'] as String,
            iamgeUrl: map['imageUrl'] as String,
            fodlerId: map['folderId'] as int?,
        );
    }
}