import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/folder.dart';
import '../models/card_model.dart';

class DB {
    DB._();
    static final DB instance = DB._();

    Database? _db;

    Future<void> init() async {
        if (_db != null) return;
        // self-note: gives app docs dir
        final dir = await getApplicationDocumentsDirectory();
        final dbPath = p.join(dir.path, 'card_organizer.db');

        _db = await openDatabase(
            dbPath,
            version: 1,
            onCreate: (db, version) async {
                // creating folders table
                await db.execute('''
                    CREATE TABLE folders (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        name TEXT NOT NULL,
                        created_at TEXT NOT NULL
                    );
                ''');

                // creating cards table
                await db.execute('''
                    CREATE TABLE cards (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        name TEXT NOT NULL,
                        suit TEXT NOT NULL,
                        imageUrl TEXT NOT NULL,
                        folderId INTEGER,
                        FOREIGN KEY(folderId) REFERENCES folders(id) ON DELETE CASCADE
                    );
                ''');

                // seed initial data
                await _seedInitialData(db);
            },
        );
    }

    Database get db => _db!; 

    // seeding helpers
    Future<void> _seedInitialData(Database db) async {
        final now = DateTime.now().toIso8601String();
        final folderNames = ['Hearts', 'Spades', 'Diamonds', 'Clubs'];

        for (final name in folderNames) {
            await db.insert('folders', {
                'name': name,
                'created_at': now,
            });
        }

        // Pre-generate a full deck of cards for each suit
        final ranks = [
            {'rank': 'A', 'label': 'Ace'},
            {'rank': '2', 'label': '2'},
            {'rank': '3', 'label': '3'},
            {'rank': '4', 'label': '4'},
            {'rank': '5', 'label': '5'},
            {'rank': '6', 'label': '6'},
            {'rank': '7', 'label': '7'},
            {'rank': '8', 'label': '8'},
            {'rank': '9', 'label': '9'},
            {'rank': '10', 'label': '10'},
            {'rank': 'J', 'label': 'Jack'},
            {'rank': 'Q', 'label': 'Queen'},
            {'rank': 'K', 'label': 'King'},
        ];

        final suitMap = {
            'Hearts': 'H',
            'Spades': 'S',
            'Diamonds': 'D',
            'Clubs': 'C',
        };

        for (final suitEntry in suitMap.entries) {
            final suitName = suitEntry.key;
            final suitCode = suitEntry.value;

            for (final r in ranks) {
                final rankCode = r['rank']!;
                final code = rankCode == '10' ? '0$suitCode' : '${rankCode}${suitCode}';
                final label = r['label']!;
                final name = '$label of $suitName';
                final image = 'https://deckofcardsapi.com/static/img/$code.png';

                await db.insert('cards', {
                    'name': name, 
                    'suit': suitName,
                    'imageUrl': image,
                    'folderId': null, // start in the deck (unassigned)
                });
            }
        }
    }

    Future<List<FolderModel>> getFolders() async {
        final rows = await db.query('folders', orderBy: 'id ASC');
        return rows.map((e) => FolderModel.fromMap(e)).toList();
    }

    Future<int> getFolderCardCount(int folderId) async {
        final result = await db.rawQuery(
            'SELECT COUNT(*) as cnt FROM cards WHERE folderId = ?',
            [folderId],
        );
        return (result.first['cnt'] as int?) ?? 0;
    }

    Future<CardModel?> getFirstCardInFolder(int folderId) async {
        final rows = await db.query(
            'cards',
            where: 'folderId = ?',
            whereArgs: [folderId],
            orderBy: 'id ASC',
            limit: 1,
        );
        if (rows.isEmpty) return null;
        return CardModel.fromMap(rows.first);
    }

    // optional folder mutations
    Future<int> insertFolder(FolderModel f) async => db.insert('folders', f.toMap());
    Future<int> updateFolder(FolderModel f) async => db.update('folders', f.toMap(), where: 'id = ?', whereArgs: [f.id]);
    Future<int> deleteFolder(int id) async => db.delete('folders', where: 'id = ?', whereArgs: [id]);

    Future<List<CardModel>> getCardsInFolder(int folderId) async {
        final rows = await db.query(
            'cards',
            where: 'folderId = ?',
            whereArgs: [folderId],
            orderBy: 'id ASC',
        );
        return rows.map((e) => CardModel.fromMap(e)).toList();
    }

    Future<List<CardModel>> getAvailableCardsBySuit(String suit) async {
        // these are cards in the deck (folderId is null) that match suit
        final rows = await db.query(
            'cards',
            where: 'folderId IS NULL AND suit = ?',
            whereArgs: [suit],
            orderBy: 'id ASC',
        );
        return rows.map((e) => CardModel.fromMap(e)).toList();
    }

    Future<int> addCardToFolder({required int cardId, required int folderId}) async {
        // check limit first (3..6). We’ll block only when >6. If it’s <3 we’ll just warn elsewhere.
        final count = await getFolderCardCount(folderId);
        if (count >= 6) {
            // I’m throwing here and catching in UI to show dialog.
            throw StateError('Folder limit reached (max 6).');
        }
        return db.update(
            'cards',
            {'folderId': folderId},
            where: 'id = ?',
            whereArgs: [cardId],
        );
    }

    Future<int> updateCard(CardModel c) async {
        return db.update('cards', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    }

    Future<int> removeCardFromFolder(int cardId) async {
        // setting folderId to null puts it back in the deck
        return db.update('cards', {'folderId': null}, where: 'id = ?', whereArgs: [cardId]);
    }

    Future<int> deleteCardPermanently(int cardId) async {
        // If you want a hard delete (probably not needed), here it is
        return db.delete('cards', where: 'id = ?', whereArgs: [cardId]);
    }
}