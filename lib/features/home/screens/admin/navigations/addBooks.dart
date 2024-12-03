import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:book_Verse/utils/constants/colors.dart';
import 'package:book_Verse/utils/helpers/helper_function.dart';

class AddBooks extends StatefulWidget {
  const AddBooks({super.key});

  @override
  _AddBooksState createState() => _AddBooksState();
}

class _AddBooksState extends State<AddBooks> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  final TextEditingController _numberOfBooksController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _writerController = TextEditingController();
  final TextEditingController _genreController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  File? _image;
  bool _isCourseBook = false;

  // List to store selected PDFs
  final List<Map<String, dynamic>> _pdfs = [];

  // Pick image from gallery
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  // Pick PDFs
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

  // Upload image to Firebase Storage
  Future<String> _uploadImage(File imageFile) async {
    String fileName = imageFile.path.split('/').last;
    TaskSnapshot snapshot = await FirebaseStorage.instance
        .ref('book_images/$fileName')
        .putFile(imageFile);
    return await snapshot.ref.getDownloadURL();
  }

  // Upload PDFs to Firebase Storage
  Future<List<Map<String, String>>> _uploadPDFs() async {
    List<Map<String, String>> uploadedPDFs = [];
    for (var pdf in _pdfs) {
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
    }
    return uploadedPDFs;
  }

  // Add book data to Firestore
  Future<void> _addBooks() async {
    if (_formKey.currentState!.validate()) {
      try {
        int numberOfBooks = int.parse(_numberOfBooksController.text);
        String? imageUrl;

        if (_image != null) {
          imageUrl = await _uploadImage(_image!);
        }

        // Parse genres if it's not a course book
        List<String>? genres = !_isCourseBook
            ? _genreController.text.split(',').map((e) => e.trim().toUpperCase()).toList()
            : null;

        // Upload PDFs
        List<Map<String, String>> pdfData = await _uploadPDFs();

        // Check if a book with the same title already exists
        final existingBooksQuery = await FirebaseFirestore.instance
            .collection('books')
            .where('title', isEqualTo: _titleController.text.trim().toUpperCase())
            .get();

        if (existingBooksQuery.docs.isNotEmpty) {
          // Show existing book details if the title matches
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Book with the same title already exists!'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Optionally, show existing books with the same title
          final existingBooks = existingBooksQuery.docs.map((doc) => doc.data()).toList();
          // You can handle the display of the existing books, for example, by showing them in a dialog or a list.
          return;
        }

        // Add the new book to Firestore
        await FirebaseFirestore.instance.collection('books').add({
          'title': _titleController.text.trim().toUpperCase(),
          'writer': _writerController.text.trim().toUpperCase(),
          'genre': genres,
          'course': _isCourseBook ? _courseController.text.trim().toUpperCase() : null,
          'grade': _isCourseBook && _gradeController.text.isNotEmpty
              ? _gradeController.text.trim().toUpperCase()
              : null,
          'imageUrl': imageUrl,
          'isCourseBook': _isCourseBook,
          'summary': _summaryController.text.trim(),
          'numberOfCopies': numberOfBooks,
          'pdfs': pdfData,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Books added successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        bool sendNotification = await _showNotificationDialog();
        if (sendNotification) {
          await _sendNotification();
        }

        _clearForm();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add books: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  // Show notification dialog
  Future<bool> _showNotificationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Send Notification'),
          content: const Text('Do you want to notify users about this book?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    ) ??
        false;
  }

  // Send notification to users
  Future<void> _sendNotification() async {
    final user = _auth.currentUser;
    if (user != null) {
      const recipientUserId = 'recipientUserId'; // Replace with dynamic recipient ID if available
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'New Book Added',
        'message': 'A new book titled "${_titleController.text.trim()}" has been added!',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'sender': user.email,
        'recipientId': recipientUserId,
      });
    }
  }

  // Clear form fields and reset states
  void _clearForm() {
    _numberOfBooksController.clear();
    _titleController.clear();
    _writerController.clear();
    _genreController.clear();
    _courseController.clear();
    _gradeController.clear();
    _summaryController.clear();
    setState(() {
      _image = null;
      _isCourseBook = false;
      _pdfs.clear();
    });
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
          'Add Books',
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
                _buildActionButton(dark),
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
          _numberOfBooksController,
          'Number of Copies',
          Icons.numbers,
          'Please enter the number of copies',
          dark,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Enter the number of copies';
            }
            final numCopies = int.tryParse(value);
            if (numCopies == null || numCopies < 0) {
              return 'Number of copies must be 0 or greater';
            }
            return null;
          },
        ),
        const SizedBox(height: 10),
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
        ],
        if (_isCourseBook) ...[
          _buildCustomTextField(
            _courseController,
            'Year / Semester',
            Icons.calendar_today,
            'Please enter year/semester',
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
      ],
    );
  }

  Widget _buildCustomTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    String validatorMessage,
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
              borderSide: BorderSide(color: TColors.primaryColor),
            ),
          ),
          validator: validator ?? (value) {
            if (value!.isEmpty) {
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
            if (_image != null) _buildImagePreview(dark),
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
              child: Image.file(_image!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => setState(() => _image = null),
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
          icon: Icon(Icons.close, color: TColors.error),
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

  Widget _buildActionButton(bool dark) {
    return ElevatedButton.icon(
      onPressed: _addBooks,
      icon: const Icon(Icons.add),
      label: const Text('Add Book'),
      style: ElevatedButton.styleFrom(
        foregroundColor: TColors.white,
        backgroundColor: TColors.success,
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
