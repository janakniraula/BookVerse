import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void showReminderPopup(BuildContext context) {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  // Flag to track if the reminder was already shown
  bool reminderShown = false;

  // Fetch current user ID
  final userId = auth.currentUser?.uid;
  if (userId == null || reminderShown) {
    return; // If no user is logged in or reminder is already shown, don't show the popup
  }

  // Query the issuedBooks collection for overdue books
  firestore.collection('issuedBooks')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .listen((snapshot) {
    if (snapshot.docs.isNotEmpty) {
      // Filter books that meet the 15-second condition
      final overdueBooks = snapshot.docs.where((doc) {
        final issueDate = (doc['issueDate'] as Timestamp).toDate();
        final currentTime = DateTime.now();
        return currentTime.difference(issueDate).inSeconds >= 5;
      }).toList();

      if (overdueBooks.isNotEmpty && !reminderShown) {
        reminderShown = true; // Prevent multiple popups

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              titlePadding: EdgeInsets.zero,
              title: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the popup immediately on single click
                    },
                  ),
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    // Title
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Reminder!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    // Divider after title
                    const Divider(
                      color: Colors.grey,
                      thickness: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                    // Notification message
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'The following books are overdue and need to be returned:',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    // List of overdue books
                    Expanded(
                      child: ListView.builder(
                        itemCount: overdueBooks.length,
                        itemBuilder: (context, index) {
                          final book = overdueBooks[index];
                          final title = book['title'] ?? 'Unknown title';
                          final issueDate = (book['issueDate'] as Timestamp).toDate();
                          // Format the issue date to a more readable format
                          String formattedDate = DateFormat('yyyy-MM-dd – kk:mm').format(issueDate);
                          return ListTile(
                            title: Text(title),
                            subtitle: Text('Issued on: $formattedDate'),
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
    }
  });
}
