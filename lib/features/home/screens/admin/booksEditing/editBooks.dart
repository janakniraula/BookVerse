import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:book_Verse/utils/constants/colors.dart';
import 'package:book_Verse/utils/helpers/helper_function.dart';

class EditBookScreen extends StatefulWidget {
  final String bookId;

  const EditBookScreen({super.key, required this.bookId});

  @override
  _EditBookScreenState createState() => _EditBookScreenState();
}

class _EditBookScreenState extends State<EditBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _writerController = TextEditingController();
  final _genreController = TextEditingController();
  final _courseController = TextEditingController();
  final _gradeController = TextEditingController();
  final _summaryController = TextEditingController();
  final TextEditingController _numberOfBooksController =
      TextEditingController();
  final _picker = ImagePicker();
  File? _image;
  String? _imageUrl;
  bool _isCourseBook = false;

  List<Map<String, dynamic>> _pdfs = [];

  @override
  void initState() {
    super.initState();
    _loadBookDetails();
  }

  Future<void> _loadBookDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('books')
          .doc(widget.bookId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _titleController.text = data['title'] ?? '';
        _writerController.text = data['writer'] ?? '';
        _courseController.text = data['course'] ?? '';
        _gradeController.text = data['grade'] ?? '';
        _summaryController.text = data['summary'] ?? '';
        _numberOfBooksController.text =
            data['numberOfCopies']?.toString() ?? '';
        _isCourseBook = data['isCourseBook'] ?? false;

        if (!_isCourseBook && data['genre'] != null) {
          _genreController.text = (data['genre'] as List).join(', ');
        }

        _imageUrl = data['imageUrl'];
        if (data['pdfs'] != null) {
          _pdfs = (data['pdfs'] as List).map((pdf) {
            return {
              'name': pdf['name'],
              'url': pdf['url'],
              'description':
                  TextEditingController(text: pdf['description'] ?? ''),
            };
          }).toList();
        }
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load book details: $e')),
      );
    }
  }

  Future<void> _deleteBook() async {
    try {
      await FirebaseFirestore.instance
          .collection('books')
          .doc(widget.bookId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Book deleted successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete book: $e')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Book'),
          content: const Text(
              'Are you sure you want to delete this book? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteBook();
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  Future<void> _pickPDFs() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _pdfs.addAll(result.files.map((file) {
          return {
            'file': File(file.path!),
            'name': file.name,
            'description': TextEditingController(),
          };
        }));
      });
    }
  }

  Future<List<Map<String, String>>> _uploadPDFs() async {
    List<Map<String, String>> uploadedPDFs = [];
    for (var pdf in _pdfs) {
      if (pdf['file'] != null) {
        String fileName = pdf['file'].path.split('/').last;
        TaskSnapshot snapshot = await FirebaseStorage.instance
            .ref('book_pdfs/$fileName')
            .putFile(pdf['file']);
        String downloadUrl = await snapshot.ref.getDownloadURL();
        uploadedPDFs.add({
          'name': pdf['name'],
          'url': downloadUrl,
          'description': pdf['description'].text,
        });
      } else {
        uploadedPDFs.add({
          'name': pdf['name'],
          'url': pdf['url'],
          'description': pdf['description'].text,
        });
      }
    }
    return uploadedPDFs;
  }

  Future<void> _updateBook() async {
    if (_formKey.currentState!.validate()) {
      try {
        String title = _titleController.text.toUpperCase();

        // Check if a book with the same title exists (excluding the current book being updated)
        var querySnapshot = await FirebaseFirestore.instance
            .collection('books')
            .where('title', isEqualTo: title)
            .get();

        if (querySnapshot.docs.isNotEmpty &&
            querySnapshot.docs.first.id != widget.bookId) {
          // If a book with the same title exists, show a pop-up
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Book with the same title already exists!'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return; // Exit the function if the book exists
        }

        String imageUrl = _imageUrl ?? '';
        if (_image != null) {
          String fileName = _image!.path.split('/').last;
          TaskSnapshot snapshot = await FirebaseStorage.instance
              .ref('book_images/$fileName')
              .putFile(_image!);
          imageUrl = await snapshot.ref.getDownloadURL();
        }

        List<String>? genres = !_isCourseBook
            ? _genreController.text
                .split(',')
                .map((e) => e.trim().toUpperCase())
                .toList()
            : null;

        // Upload PDFs
        List<Map<String, String>> pdfData = await _uploadPDFs();

        await FirebaseFirestore.instance
            .collection('books')
            .doc(widget.bookId)
            .update({
          'title': title,
          'writer': _writerController.text.toUpperCase(),
          'genre': genres,
          'course': _isCourseBook ? _courseController.text.toUpperCase() : null,
          'grade':
              _isCourseBook && _gradeController.text.toUpperCase().isNotEmpty
                  ? _gradeController.text.toUpperCase()
                  : null,
          'imageUrl': imageUrl,
          'isCourseBook': _isCourseBook,
          'summary': _summaryController.text.toUpperCase(),
          'numberOfCopies': int.tryParse(_numberOfBooksController.text) ?? 0,
          'pdfs': pdfData, // Updated PDFs
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book updated successfully')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update book: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = THelperFunction.isDarkMode(context);
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Book',
          style: TextStyle(color: TColors.white),
        ),
        centerTitle: true,
        backgroundColor: TColors.primaryColor,
        foregroundColor: TColors.white,
      ),
      body: Container(
        color: dark ? TColors.dark : TColors.light,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                _buildSwitchTile(dark),
                const SizedBox(height: 20),
                _buildMainForm(dark),
                const SizedBox(height: 20),
                _buildImageSection(dark),
                const SizedBox(height: 20),
                _buildPDFSection(dark),
                const SizedBox(height: 20),
                _buildActionButtons(dark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(bool dark) {
    return Card(
      color: dark ? TColors.darkContainer : TColors.white,
      elevation: 0,
      child: SwitchListTile(
        title: Text(
          'Is this a course book?',
          style: TextStyle(
            color: dark ? TColors.white : TColors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        value: _isCourseBook,
        activeColor: TColors.primaryColor,
        onChanged: (value) => setState(() => _isCourseBook = value),
      ),
    );
  }

  Widget _buildMainForm(bool dark) {
    return Column(
      children: [
        _buildCustomTextField(
          _titleController,
          'Book Title',
          Icons.book,
          'Please enter the book title',
          dark,
        ),
        const SizedBox(height: 10),
        _buildCustomTextField(
          _writerController,
          'Writer',
          Icons.person,
          'Please enter the writer name',
          dark,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a valid writer name';
            }
            if (RegExp(r'\d').hasMatch(value)) {
              return 'Writer name should not contain numbers';
            }
            return null;
          },
        ),
        const SizedBox(height: 10),
        if (!_isCourseBook) ...[
          _buildCustomTextField(
            _genreController,
            'Genre (comma-separated)',
            Icons.category,
            'Please enter genres',
            dark,
          ),
          const SizedBox(height: 10),
        ],
        if (_isCourseBook) ...[
          _buildCustomTextField(
            _courseController,
            'Year / Semester',
            Icons.calendar_today,
            null,
            dark,
          ),
          const SizedBox(height: 10),
          _buildCustomTextField(
            _gradeController,
            'Grade',
            Icons.grade,
            'Please enter the grade',
            dark,
          ),
        ],
        const SizedBox(height: 10),
        _buildCustomTextField(
          _summaryController,
          'Summary',
          Icons.description,
          'Please enter a summary',
          dark,
          maxLines: 3,
        ),
        const SizedBox(height: 10),
        _buildCustomTextField(
          _numberOfBooksController,
          'Number of Copies',
          Icons.numbers,
          'Please enter the number of copies',
          dark,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the number of copies';
            }
            final numCopies = int.tryParse(value);
            if (numCopies == null) {
              return 'Please enter a valid number';
            }
            if (numCopies < 0) {
              return 'Number of copies cannot be negative';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCustomTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    String? validatorMessage,
    bool dark, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Card(
      color: dark ? TColors.darkContainer : TColors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: dark ? TColors.white : TColors.black),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: dark ? TColors.white.withOpacity(0.7) : TColors.black.withOpacity(0.87)
            ),
            prefixIcon: Icon(icon, color: TColors.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: dark ? TColors.darkGrey : TColors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: dark ? TColors.darkGrey : TColors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TColors.primaryColor),
            ),
          ),
          validator: validator ?? (value) {
            if (validatorMessage != null && value!.isEmpty) {
              return validatorMessage;
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildImageSection(bool dark) {
    return Card(
      color: dark ? TColors.darkContainer : TColors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Book Cover Image',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: dark ? TColors.white : TColors.black,
              ),
            ),
            const SizedBox(height: 16),
            if (_image != null || (_imageUrl != null && _imageUrl!.isNotEmpty))
              _buildImagePreview(dark),
            const SizedBox(height: 16),
            _buildImagePickerButton(dark),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(bool dark) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: TColors.primaryColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: _image != null
                  ? Image.file(_image!, fit: BoxFit.cover)
                  : Image.network(_imageUrl!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => setState(() {
                _image = null;
                _imageUrl = null;
              }),
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: TColors.error.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: TColors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickerButton(bool dark) {
    return ElevatedButton.icon(
      onPressed: _pickImage,
      icon: const Icon(Icons.image),
      label: const Text('Pick Image'),
      style: ElevatedButton.styleFrom(
        foregroundColor: TColors.white,
        backgroundColor: TColors.primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildPDFSection(bool dark) {
    return Card(
      color: dark ? TColors.darkContainer : TColors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PDF Documents',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: dark ? TColors.white : TColors.black,
              ),
            ),
            const SizedBox(height: 16),
            if (_pdfs.isNotEmpty) ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pdfs.length,
                itemBuilder: (context, index) => _buildPDFItem(_pdfs[index], dark),
              ),
              const SizedBox(height: 16),
            ],
            _buildPDFPickerButton(dark),
          ],
        ),
      ),
    );
  }

  Widget _buildPDFItem(Map<String, dynamic> pdf, bool dark) {
    return Card(
      color: dark ? TColors.darkContainer.withOpacity(0.3) : TColors.lightContainer,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          pdf['name'],
          style: TextStyle(
            color: dark ? TColors.white.withOpacity(0.7) : TColors.black.withOpacity(0.87)
          ),
        ),
        subtitle: TextField(
          controller: pdf['description'],
          style: TextStyle(
            color: dark ? TColors.white.withOpacity(0.7) : TColors.black.withOpacity(0.54)
          ),
          decoration: InputDecoration(
            labelText: 'Description (optional)',
            labelStyle: TextStyle(
              color: dark ? TColors.white.withOpacity(0.7) : TColors.black.withOpacity(0.54)
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, color: TColors.error),
          onPressed: () => setState(() => _pdfs.remove(pdf)),
        ),
      ),
    );
  }

  Widget _buildPDFPickerButton(bool dark) {
    return ElevatedButton.icon(
      onPressed: _pickPDFs,
      icon: const Icon(Icons.picture_as_pdf),
      label: const Text('Pick PDFs'),
      style: ElevatedButton.styleFrom(
        foregroundColor: TColors.white,
        backgroundColor: TColors.primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildActionButtons(bool dark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _updateBook,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: TColors.white,
                  backgroundColor: TColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: TColors.white,
                  backgroundColor: TColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete Book'),
            style: ElevatedButton.styleFrom(
              foregroundColor: TColors.white,
              backgroundColor: TColors.error,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
