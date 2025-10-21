import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/folder.dart';
import '../models/card_model.dart';

class CardsScreen extends StatefulWidget {
    final FolderModel folder;
    const CardsScreen({super.key, required this.folder});

    @override
    State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
    late Future<List<CardModel>> _cardsFuture;

    @override
    void initState() {
        super.initState();
        _load();
    }

    void _load() {
        // load cards currently in this folder
        _cardsFuture = DB.instance.getCardsInFolder(widget.folder.id!);
        setState(() {});
    }

    Future<void> _addCard() async {
        // When adding, we only allow picking from the deck where suit matches folder
        final suit = widget.folder.name; // Hearts/Spades/etc

        final available = await DB.instance.getAvailableCardsBySuit(suit);
        if (available.isEmpty) {
        // not the end of the world; just tell the user
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No more cards available in the deck for this suit.')),
            );
        }
        return;
        }

        // show a bottom sheet to pick one card
        if (!mounted) return;
        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) {
                return SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text('Add a ${widget.folder.name} card', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                SizedBox(
                                    height: 280,
                                    child: ListView.separated(
                                        itemCount: available.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                        itemBuilder: (context, i) {
                                            final c = available[i];
                                            return ListTile(
                                                leading: ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Image.network(
                                                        c.imageUrl,
                                                        width: 40,
                                                        height: 60,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (cxt, err, st) => const Icon(Icons.image_outlined),
                                                    ),
                                                ),
                                                title: Text(c.name),
                                                trailing: IconButton(
                                                    icon: const Icon(Icons.add_circle_outline),
                                                    onPressed: () async {
                                                        try {
                                                            await DB.instance.addCardToFolder(cardId: c.id!, folderId: widget.folder.id!);
                                                            if (mounted) Navigator.of(context).pop();
                                                            _load();
                                                            if (mounted) {
                                                                final count = await DB.instance.getFolderCardCount(widget.folder.id!);
                                                                // if hearts, we just warn; we don’t block adds (assignment says warn)
                                                                if (count < 3) {
                                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                                        SnackBar(content: Text('Heads up: ${widget.folder.name} has only $count card(s). You need at least 3.')),
                                                                    );
                                                                }
                                                            }
                                                        } catch (e) {
                                                        // most likely the 6-card limit
                                                            if (mounted) {
                                                                _showErrorDialog('This folder can only hold 6 cards.');
                                                            }
                                                        }
                                                    },
                                                ),
                                            );
                                        },
                                    ),
                                ),
                            ],
                        ),
                    ),
                );
            },
        );
    }

    Future<void> _showErrorDialog(String message) {
        return showDialog(
            context: context,
            builder: (context) => AlertDialog(
                title: const Text('Limit Reached'),
                content: Text(message),
                actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
            ),
        );
    }

    Future<void> _removeCard(CardModel c) async {
        // I won’t block deletion (assignment says show warning if hearts). So we’ll warn after.
        await DB.instance.removeCardFromFolder(c.id!);
        _load();
        if (!mounted) return;
        final count = await DB.instance.getFolderCardCount(widget.folder.id!);
        if (count < 3) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Warning: ${widget.folder.name} now has only $count card(s). You need at least 3.')),
            );
        }
    }

    Future<void> _editCard(CardModel c) async {
        // Simple edit: allow changing name or moving to another folder 
        // Keeping it straightforward with a dialog.
        final nameCtrl = TextEditingController(text: c.name);
        int? selectedFolderId = widget.folder.id;

        // load all folders to choose a different one if we want
        final folders = await DB.instance.getFolders();

        if (!mounted) return;
        showDialog(
        context: context,
        builder: (context) {
            return AlertDialog(
                title: const Text('Edit Card'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(labelText: 'Card name'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                            value: selectedFolderId,
                            items: [
                                for (final f in folders)
                                    DropdownMenuItem<int>(
                                        value: f.id,
                                        child: Text(f.name),
                                    ),
                                ],
                                onChanged: (v) => selectedFolderId = v,
                                decoration: const InputDecoration(labelText: 'Folder'),
                            ),
                        ],
                    ),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                            onPressed: () async {
                                // If moving to another folder, I should check the 6-card limit.
                                if (selectedFolderId != null && selectedFolderId != c.folderId) {
                                    final count = await DB.instance.getFolderCardCount(selectedFolderId!);
                                    if (count >= 6) {
                                        if (context.mounted) {
                                            Navigator.of(context).pop(); // close dialog
                                            _showErrorDialog('Max Capacity = 6 cards');
                                        }
                                        return; // exits to prevent any updates
                                    }
                                }
                                // Now safe to update
                                final updated = CardModel(
                                    id: c.id,
                                    name: nameCtrl.text.trim().isEmpty ? c.name : nameCtrl.text.trim(),
                                    suit: c.suit,
                                    imageUrl: c.imageUrl,
                                    folderId: selectedFolderId,
                                );
                                await DB.instance.updateCard(updated);
                                if (context.mounted) Navigator.of(context).pop();
                                _load(); // refreshes UI
                            },
                            child: const Text('Save'),
                        ),
                    ],
                );
            },
        );
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: Text(widget.folder.name),
                actions: [
                    IconButton(
                        tooltip: 'Add card from deck',
                        onPressed: _addCard,
                        icon: const Icon(Icons.add),
                    )
                ],
            ),
            body: FutureBuilder<List<CardModel>>(
                future: _cardsFuture,
                builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                        return Center(child: Text('Oops: ${snapshot.error}'));
                    }
                    final cards = snapshot.data ?? [];
                    if (cards.isEmpty) {
                        return const Center(
                            child: Text('No cards here yet. Try adding a few using the + button.'),
                        );
                    }

                    // Using GridView to display cards nicely.
                    return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.7, // a bit taller because playing cards are tall
                        ),
                        itemCount: cards.length,
                        itemBuilder: (context, index) {
                            final c = cards[index];
                            return _CardTile(
                                card: c,
                                onDelete: () => _removeCard(c),
                                onEdit: () => _editCard(c),
                            );
                        },
                    );
                },
            ),
        );
    }
}

class _CardTile extends StatelessWidget {
    final CardModel card;
    final VoidCallback onDelete;
    final VoidCallback onEdit;

    const _CardTile({required this.card, required this.onDelete, required this.onEdit});

    @override
    Widget build(BuildContext context) {
        return Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).cardColor,
                boxShadow: [
                    BoxShadow(
                        blurRadius: 10,
                        spreadRadius: 1,
                        color: Colors.black.withOpacity(0.08),
                    )
                ],
            ),
            child: Column(
                children: [
                    Expanded(
                        child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.network(
                                card.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Center(child: Icon(Icons.image_outlined, size: 48)),
                            ),
                        ),
                    ),
                    Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                Text(
                                    card.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        IconButton(
                                            tooltip: 'Edit card',
                                            icon: const Icon(Icons.edit_outlined),
                                            onPressed: onEdit,
                                        ),
                                        IconButton(
                                            tooltip: 'Remove from folder',
                                            icon: const Icon(Icons.delete_outline),
                                            onPressed: onDelete,
                                        ),
                                    ],
                                ),
                            ],
                        ),
                    ),
                ],
            ),
        );
    }
}
