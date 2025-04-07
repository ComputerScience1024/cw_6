import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData) return const TaskListScreen();
          return const AuthScreen();
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> signIn() async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailController.text,
      password: passwordController.text,
    );
  }

  Future<void> register() async {
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: emailController.text,
      password: passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login or Register")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
          TextField(controller: passwordController, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(onPressed: signIn, child: const Text("Login")),
              ElevatedButton(onPressed: register, child: const Text("Register")),
            ],
          )
        ]),
      ),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  TaskListScreenState createState() => TaskListScreenState();
}

class TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController taskController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  Future<void> addTask(String name) async {
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('tasks').add({
      'name': name,
      'completed': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleComplete(String id, bool complete) async {
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('tasks').doc(id).update({
      'completed': complete,
    });
  }

  Future<void> deleteTask(String id) async {
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('tasks').doc(id).delete();
  }

  Widget buildSubTasks(String parentId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('tasks')
          .doc(parentId)
          .collection('subtasks')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return Column(
          children: snapshot.data!.docs.map((doc) {
            return ListTile(
              title: Text(doc['name']),
              leading: Checkbox(
                value: doc['completed'],
                onChanged: (val) {
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('tasks')
                      .doc(parentId)
                      .collection('subtasks')
                      .doc(doc.id)
                      .update({'completed': val});
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tasks"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(children: [
              Expanded(child: TextField(controller: taskController, decoration: const InputDecoration(labelText: "New Task"))),
              ElevatedButton(
                onPressed: () {
                  if (taskController.text.isNotEmpty) {
                    addTask(taskController.text);
                    taskController.clear();
                  }
                },
                child: const Text("Add"),
              ),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('tasks').orderBy('timestamp').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Checkbox(
                              value: doc['completed'],
                              onChanged: (val) => toggleComplete(doc.id, val!),
                            ),
                            Expanded(child: Text(doc['name'])),
                            IconButton(icon: const Icon(Icons.delete), onPressed: () => deleteTask(doc.id)),
                          ],
                        ),
                        children: [buildSubTasks(doc.id)],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
