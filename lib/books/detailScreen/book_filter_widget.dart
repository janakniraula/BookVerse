import 'package:flutter/material.dart';

class BookFilterWidget extends StatefulWidget {
  final String currentAuthor;
  final List<String> availableGenres;
  final Function(String?, List<String>) onFilterChanged;
  final List<String> selectedGenres;

  const BookFilterWidget({
    super.key,
    required this.currentAuthor,
    required this.availableGenres,
    required this.onFilterChanged,
    required this.selectedGenres,
  });

  @override
  State<BookFilterWidget> createState() => _BookFilterWidgetState();
}

class _BookFilterWidgetState extends State<BookFilterWidget> {
  late List<String> _selectedGenres;
  bool get hasFilters => _selectedGenres.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedGenres = List.from(widget.selectedGenres);
  }

  void _applyFilters() {
    widget.onFilterChanged(widget.currentAuthor, _selectedGenres);
    Navigator.pop(context);
  }

  void _clearFilters() {
    setState(() => _selectedGenres.clear());
    widget.onFilterChanged(widget.currentAuthor, []);
    Navigator.pop(context);
  }

  void _toggleGenre(String genre, bool selected) {
    setState(() {
      if (selected) {
        _selectedGenres.add(genre);
      } else {
        _selectedGenres.remove(genre);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 16),
          _buildAuthorSection(isDark),
          const SizedBox(height: 16),
          _buildGenresSection(isDark),
          const SizedBox(height: 20),
          _buildActionButtons(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Filter Books',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildAuthorSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Author',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            ),
          ),
          child: Text(
            widget.currentAuthor,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenresSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Genres',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: widget.availableGenres.map((genre) => _buildGenreChip(genre, isDark)).toList(),
        ),
      ],
    );
  }

  Widget _buildGenreChip(String genre, bool isDark) {
    final isSelected = _selectedGenres.contains(genre);
    
    return FilterChip(
      label: Text(
        genre,
        style: TextStyle(
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.blue,
      showCheckmark: false,
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
      side: BorderSide(
        color: isSelected ? Colors.blue : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      onSelected: (selected) => _toggleGenre(genre, selected),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: hasFilters ? Colors.blue : Colors.white,
      foregroundColor: hasFilters ? Colors.white : Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: hasFilters ? Colors.blue : Colors.black,
          width: 1,
        ),
      ),
    );

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _clearFilters,
            icon: Icon(
              Icons.clear_all,
              size: 20,
              color: hasFilters ? Colors.white : Colors.black,
            ),
            label: Text(
              'Clear Filters',
              style: TextStyle(
                color: hasFilters ? Colors.white : Colors.black,
                fontSize: 14,
              ),
            ),
            style: buttonStyle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _applyFilters,
            icon: Icon(
              Icons.check,
              size: 20,
              color: hasFilters ? Colors.white : Colors.black,
            ),
            label: Text(
              'Apply Filters',
              style: TextStyle(
                color: hasFilters ? Colors.white : Colors.black,
                fontSize: 14,
              ),
            ),
            style: buttonStyle,
          ),
        ),
      ],
    );
  }
} 