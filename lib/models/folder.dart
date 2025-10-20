class FolderModel {
    final int? id;
    final String name;
    final String createdAt;

    FolderModel({
        this.iod,
        required this.name,
        required this.createdAt,
    });

    // Convert a FolderModel into a Map to insert into SQLite
    Map<String, dynamic>? toMap() {
        return {
            'id': id,
            'name': name,
            'createdAt': createdAt,
        };
    }

    // Convert a Map from SQLite back into a FolderModel
    factory FolderModel.fromMap.fromMap(Map<String, dynamic> map) {
        return FolderModel(
            id: map['id'],
            name: map['name'],
            createAt: map['create_at'],
        );
    }
}
