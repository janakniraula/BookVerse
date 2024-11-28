import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utils/constants/sizes.dart';
import '../../../../../books/detailScreen/course_book_detail_screen.dart';
import '../../../utils/device/device_utility.dart';

class TAppBar extends StatefulWidget implements PreferredSizeWidget {
  const TAppBar({
    super.key,
    this.title,
    this.leadingIcon,
    this.actions,
    this.leadingOnProgress,
    this.showBackArrow = false,
    this.showSearchBox = false,
  });

  final Widget? title;
  final bool showBackArrow;
  final IconData? leadingIcon;
  final List<Widget>? actions;
  final VoidCallback? leadingOnProgress;
  final bool showSearchBox;

  @override
  State<TAppBar> createState() => _TAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(
        showSearchBox
            ? TDeviceUtils.getAppBarHeight() + 150
            : TDeviceUtils.getAppBarHeight(),
      );
}

class _TAppBarState extends State<TAppBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _setupSearchListeners();
  }

  void _setupSearchListeners() {
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _clearSearch();
      }
    });

    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      } else {
        _performSearch(_searchController.text);
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchResults = [];
      _searchController.clear();
      _isSearching = false;
      _focusNode.unfocus();
      _searchController.selection = const TextSelection.collapsed(offset: -1);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('books').get();

      if (!mounted) return;

      setState(() {
        _searchResults = snapshot.docs.where((doc) {
          final data = doc.data();
          final title = data['title']?.toString().toUpperCase() ?? '';
          final writer = data['writer']?.toString().toUpperCase() ?? '';
          final searchQuery = query.toUpperCase();
          return title.contains(searchQuery) || writer.contains(searchQuery);
        }).toList();
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        _clearSearch();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TSizes.md),
        child: Column(
          children: [
            _buildAppBar(),
            if (widget.showSearchBox) ...[
              _buildSearchBar(),
              if (_searchResults.isNotEmpty) _buildSearchResults(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: widget.showBackArrow
          ? IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Iconsax.arrow_left, color: Colors.white),
            )
          : widget.leadingIcon != null
              ? IconButton(
                  onPressed: widget.leadingOnProgress,
                  icon: Icon(widget.leadingIcon!),
                )
              : null,
      title: widget.title,
      actions: widget.actions,
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search books...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon:
              Icon(Iconsax.search_normal, color: Colors.white.withOpacity(0.7)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final book = _searchResults[index].data() as Map<String, dynamic>;
          return _buildSearchResultItem(book);
        },
      ),
    );
  }

  Widget _buildSearchResultItem(Map<String, dynamic> book) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          book['imageUrl'] ?? '',
          width: 45,
          height: 65,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 45,
            height: 65,
            color: Colors.grey.shade200,
            child: const Icon(Icons.book, color: Colors.grey),
          ),
        ),
      ),
      title: Text(
        book['title'] ?? 'No title',
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        book['writer'] ?? 'Unknown author',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        _clearSearch();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseBookDetailScreen(
              title: book['title'] ?? 'No title',
              writer: book['writer'] ?? 'Unknown author',
              imageUrl: book['imageUrl'] ?? '',
              course: book['course'] ?? '',
              summary: book['summary'] ?? 'No summary available',
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
