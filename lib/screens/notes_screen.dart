import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notes_provider.dart';
import '../models/note_model.dart';
import 'package:uuid/uuid.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTag = 'all';
  String _selectedType = 'all';

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);

    // Get all unique tags
    final allTags = <String>{'all'};
    for (var note in notes) {
      allTags.addAll(note.tags);
    }

    // Filter notes based on search, tags, and types
    final searchQuery = _searchController.text.toLowerCase();
    final filteredNotes = notes.where((note) {
      final matchesSearch = note.title.toLowerCase().contains(searchQuery) ||
          (note.content?.toLowerCase().contains(searchQuery) ?? false) ||
          (note.subject?.toLowerCase().contains(searchQuery) ?? false);
      
      final matchesTag = _selectedTag == 'all' || note.tags.contains(_selectedTag);
      final matchesType = _selectedType == 'all' || note.type == _selectedType;

      return matchesSearch && matchesTag && matchesType;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          // Search & Filters bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes, subjects...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Filters list (Types & Tags)
          _buildFilterScroll(allTags),

          const Divider(height: 1),

          // Notes List
          Expanded(
            child: _buildNotesList(filteredNotes),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNoteDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterScroll(Set<String> allTags) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          // Type filter
          DropdownButton<String>(
            value: _selectedType,
            underline: const SizedBox(),
            icon: const Icon(Icons.filter_list),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Types')),
              DropdownMenuItem(value: 'text', child: Text('Text Notes')),
              DropdownMenuItem(value: 'pdf', child: Text('PDF Files')),
              DropdownMenuItem(value: 'image', child: Text('Images/Photos')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedType = val;
                });
              }
            },
          ),
          const SizedBox(width: 12),
          // Tag filters
          ...allTags.map((tag) {
            final isSelected = tag == _selectedTag;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text('#$tag'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedTag = selected ? tag : 'all';
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotesList(List<NoteModel> filteredNotes) {
    if (filteredNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: Theme.of(context).dividerColor),
            const SizedBox(height: 16),
            Text(
              'No notes found.',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: filteredNotes.length,
      itemBuilder: (context, index) {
        final note = filteredNotes[index];
        IconData typeIcon = Icons.article_outlined;
        if (note.type == 'pdf') typeIcon = Icons.picture_as_pdf_outlined;
        if (note.type == 'image') typeIcon = Icons.image_outlined;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(typeIcon, color: Theme.of(context).primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        note.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    // Action dropdown (delete / summarize)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        if (val == 'delete') {
                          ref.read(notesProvider.notifier).deleteNote(note.id);
                        } else if (val == 'summarize') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Generating AI summary...')),
                          );
                          ref.read(notesProvider.notifier).summarizeNote(note.id);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'summarize',
                          child: Text('AI Summarize'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ],
                ),
                if (note.subject != null || note.category != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${note.subject ?? ""} • ${note.category ?? ""}'.trim(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (note.content != null && note.content!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    note.content!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
                if (note.summary != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 14, color: Colors.indigoAccent),
                            SizedBox(width: 6),
                            Text(
                              'AI SUMMARY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigoAccent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          note.summary!,
                          style: const TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: note.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddNoteDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final subjectController = TextEditingController();
    final categoryController = TextEditingController();
    final tagsController = TextEditingController();
    String noteType = 'text';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New Note'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      value: noteType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'text', child: Text('Text Note')),
                        DropdownMenuItem(value: 'pdf', child: Text('Link PDF (Simulated)')),
                        DropdownMenuItem(value: 'image', child: Text('Link Image (Simulated)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            noteType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(hintText: 'Note Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(hintText: 'Subject (e.g. DBMS, Math)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(hintText: 'Category (e.g. Lecture, Study)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tagsController,
                      decoration: const InputDecoration(hintText: 'Tags (comma separated, e.g. unit4, exam)'),
                    ),
                    if (noteType == 'text') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: contentController,
                        maxLines: 5,
                        decoration: const InputDecoration(hintText: 'Content Body'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;

                    final List<String> tagsList = tagsController.text.isEmpty
                        ? []
                        : tagsController.text
                            .split(',')
                            .map((t) => t.trim().toLowerCase())
                            .where((t) => t.isNotEmpty)
                            .toList();

                    final newNote = NoteModel(
                      id: const Uuid().v4(),
                      title: titleController.text.trim(),
                      content: noteType == 'text' ? contentController.text.trim() : 'Linked simulated file document.',
                      type: noteType,
                      subject: subjectController.text.trim().isEmpty ? null : subjectController.text.trim(),
                      category: categoryController.text.trim().isEmpty ? 'General' : categoryController.text.trim(),
                      updatedAt: DateTime.now().toIso8601String(),
                      tags: tagsList,
                      filePath: noteType != 'text' ? 'simulated_path_to_${titleController.text.trim()}.$noteType' : null,
                    );

                    ref.read(notesProvider.notifier).addNote(newNote);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
