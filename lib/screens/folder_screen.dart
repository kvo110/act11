import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/folder.dart';
import '../models/card_model.dart';
import 'cards_screen.dart';

class FolderScreen extends StatefulWidget {
    const FolderScreen({super.key});

    @override
    State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
    late Future<List<FolderModel>> _foldersFuture;

    @override
    void initState() {
        super.initState();
        _foldersFuture = DB.instance.getFolders();
    }

    Future<void> _refresh() async {
        setState(() {
            _foldersFuture = DB.instance.getFolders();
        });
    }

    @override
    Widget build(BuildCOntext context) {
        return Scaffold(
            appBar: AppBar(
                title: const Text('Card Organizer'),
            ),
            body: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<FolderModel>>(
                    future: _foldersFuture,
                    builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        final folders = snapshot.data ?? [];
                        if (folders.isEmpty) {
                            return const Center(child: Text('Finding folders...'));
                        }
                        // Using a grid for aesthetics
                        return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.0,
                            ),
                            itemCount: folders.length,
                            itemBuilder: (context, index) {
                                final f = folders[index];
                                return _FolderCard(folder: f, onOpen: () async {
                                    await Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => CardsScreen(folder: f),
                                        ),
                                    );
                                    // refresh the counts/preview when you come back
                                    await _refresh();
                                });
                            },
                        );
                    },
                ),
            ),
        );
    }
}

class _FolderCard extends StatelessWidget {
    final FolderModel folder;
    final VoidCallback onOpen;
    const _FolderCard({required this.folder, required this.onOpen});

    @override 
    Widget build(BuildContext context) {
        return InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(16),
            child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    colro: Theme.of(context).cardColor,
                    boxShadow: [
                        BoxShadow(
                            blurRadius: 10,
                            spreadRadius: 1,
                            color: Colors.black.withOpacity(0.08),
                        )
                    ],
                ),
                padding: const EdgeInsets.all(12),
                child: FutureBuilder(
                    // grabbing preview card and count together
                    future: Future.wait([
                        DB.instance.getFirstCardInFolder(folder.id!),
                        DB.instance.getFolderCardCount(folder.id!),
                    ]),
                    builder: (context, snapshot) {
                        CardModel? preview;
                        int count = 0;
                        if (snapshot.hasData) {
                            final list = snapshot.data!;
                            preview = list[0] as CardModel?;
                            count = list[1] as int;
                        }

                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                Expanded(
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: preview != null 
                                            ? Image.network(
                                                preview.imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, s) => _placeholder(),
                                            ) : _placeholder(),
                                    ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    folder.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text('$count card${count == 1 ? '' : 's'}'),
                            ],
                        );
                    },
                ),
            ),
        );
    }

    Widget _placeholder() {
        // fallback in case of no previews
        return Container(
            color: Colors.grey.withOpacity(0.2),
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported_outlined),
        );
    }
}