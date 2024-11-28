import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

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
  final TextEditingController _numberOfBooksController = TextEditingController();
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
      final doc = await FirebaseFirestore.instance.collection('books').doc(widget.bookId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _titleController.text = data['title'] ?? '';
        _writerController.text = data['writer'] ?? '';
        _courseController.text = data['course'] ?? '';
        _gradeController.text = data['grade'] ?? '';
        _summaryController.text = data['summary'] ?? '';
        _numberOfBooksController.text = data['numberOfCopies']?.toString() ?? '';
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
              'description': TextEditingController(text: pdf['description'] ?? ''),
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
      await FirebaseFirestore.instance.collection('books').doc(widget.bookId).delete();
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
          content: const Text('Are you sure you want to delete this book? This action cannot be undone.'),
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

        await FirebaseFirestore.instance.collection('books').doc(widget.bookId).update({
          'title': title,
          'writer': _writerController.text.toUpperCase(),
          'genre': genres,
          'course': _isCourseBook ? _courseController.text.toUpperCase() : null,
          'grade': _isCourseBook && _gradeController.text.toUpperCase().isNotEmpty
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





  Widget _buildTextFields(
      TextEditingController controller,
      String labelText,
      IconData icon,
      String validationMessage,
      ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return validationMessage;
        }
        final numCopies = int.tryParse(value);
        if (numCopies == null) {
          return 'Please enter a valid number';
        }
        // Allow zero and any positive number
        if (numCopies < 0) {
          return 'Number of copies cannot be negative';
        }
        return null;
      },
    );

  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Book'),
        centerTitle: true,
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SwitchListTile(
                title: const Text('Is this a course book?'),
                value: _isCourseBook,
                activeColor: Colors.deepOrangeAccent,
                onChanged: (value) {
                  setState(() {
                    _isCourseBook = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              _buildTextField(_titleController, 'Book Title', Icons.book, 'Please enter the book title'),
              const SizedBox(height: 10),
              _buildStringValidatedTextFormField(_writerController, 'Writer', Icons.person,),
              const SizedBox(height: 10),
              if (!_isCourseBook)
                Column(
                  children: [
                    _buildStringValidatedTextFormField(_genreController, 'Genre (comma-separated)', Icons.category,),
                    const SizedBox(height: 10),
                  ],
                ),
              if (_isCourseBook)
                Column(
                  children: [
                    _buildTextField(_courseController, 'Year / Semester (optional)', Icons.calendar_today),
                    const SizedBox(height: 10),
                    _buildTextField(_gradeController, 'Grade', Icons.grade, 'Please enter the grade'),
                    const SizedBox(height: 10),
                  ],
                ),
              _buildTextField(_summaryController, 'Summary', Icons.description, 'Please enter a summary'),
              const SizedBox(height: 10),
              _buildTextFields(
                _numberOfBooksController,
                'Number of Copies',
                Icons.numbers,
                'Please enter the number of copies',
              ),
              const SizedBox(height: 20),
              if (_image != null || (_imageUrl != null && _imageUrl!.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        const Text(
                          'Image',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Stack(
                          children: [
                            SizedBox(
                              height: 120,
                              width: 120,
                              child: _image != null
                                  ? Image.file(_image!, fit: BoxFit.cover)
                                  : Image.network(_imageUrl!, fit: BoxFit.cover),
                            ),
                            if (_image != null || _imageUrl != null)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _image = null;
                                      _imageUrl = null;
                                    });
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Pick Image'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(120, 40),
                ),
              ),
              const SizedBox(height: 20),
              if (_pdfs.isNotEmpty)
                Column(
                  children: _pdfs.map((pdf) {
                    return Card(
                      child: ListTile(
                        title: Text(pdf['name']),
                        subtitle: TextField(
                          controller: pdf['description'],
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _pdfs.remove(pdf);
                            });
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _pickPDFs,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Pick PDFs'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.teal,
                  minimumSize: const Size(120, 40),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _updateBook,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                      minimumSize: const Size(150, 40),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                      minimumSize: const Size(150, 40),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete),
                label: const Text('Delete Book'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size(200, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildStringValidatedTextFormField(
      TextEditingController controller, String labelText, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value
            .trim()
            .isEmpty) {
          return 'Please enter a valid $labelText';
        }
        if (RegExp(r'\d').hasMatch(value)) {
          return '$labelText should not contain numbers';
        }
        return null;
      },
    );
  }
  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, [
        String? validatorMessage,
        TextInputType inputType = TextInputType.text,
        int maxLines = 1,
        String? Function(String?)? validator,
      ]) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      keyboardType: inputType,
      maxLines: maxLines,
      validator: validator ??
              (value) {
            if (validatorMessage != null && value!.isEmpty) return validatorMessage;
            return null;
          },
    );
  }
}
