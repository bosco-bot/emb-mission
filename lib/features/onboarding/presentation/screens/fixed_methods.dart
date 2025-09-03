import 'package:flutter/material.dart';

// Deuxième page d'onboarding - Bienvenue dans EMB Mission
Widget _buildSecondPage() {
  return Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
    child: SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.favorite, color: Colors.red, size: 80),
          SizedBox(height: 32),
          Text(
            'Bienvenue dans EMB Mission',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            'Une application pour nourrir ta foi, prier, écouter, partager et grandir dans la communauté chrétienne.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// Troisième page d'onboarding - Fonctionnalités principales
Widget _buildThirdPage() {
  return Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Fonctionnalités principales',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),
          ListTile(
            leading: Icon(Icons.menu_book, color: Colors.blue),
            title: Text('Lire la Bible'),
            subtitle: Text('Accède à la Bible et à des plans de lecture adaptés.'),
          ),
          ListTile(
            leading: Icon(Icons.headphones, color: Colors.green),
            title: Text('Écouter des enseignements'),
            subtitle: Text('Podcasts, replays, contenus audio pour t’inspirer.'),
          ),
          ListTile(
            leading: Icon(Icons.people, color: Colors.orange),
            title: Text('Communauté'),
            subtitle: Text('Partage, prie et échange avec d’autres membres.'),
          ),
        ],
      ),
    ),
  );
}
