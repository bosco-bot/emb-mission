import 'package:flutter/material.dart';

// Deuxième page d'onboarding - Bienvenue dans EMB Mission
Widget _buildSecondPage({required VoidCallback onNext, required VoidCallback onPrevious}) {
  return Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
    child: SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite, color: Colors.red, size: 80),
          const SizedBox(height: 32),
          const Text(
            'Bienvenue dans EMB Mission',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Une application pour nourrir ta foi, prier, écouter, partager et grandir dans la communauté chrétienne.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: onPrevious,
                child: const Text('Précédent'),
              ),
              ElevatedButton(
                onPressed: onNext,
                child: const Text('Suivant'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// Troisième page d'onboarding - Fonctionnalités principales
Widget _buildThirdPage({required VoidCallback onNext, required VoidCallback onPrevious}) {
  return Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fonctionnalités principales',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const ListTile(
            leading: Icon(Icons.menu_book, color: Colors.blue),
            title: Text('Lire la Bible'),
            subtitle: Text('Accède à la Bible et à des plans de lecture adaptés.'),
          ),
          const ListTile(
            leading: Icon(Icons.headphones, color: Colors.green),
            title: Text('Écouter des enseignements'),
            subtitle: Text('Podcasts, replays, contenus audio pour t’inspirer.'),
          ),
          const ListTile(
            leading: Icon(Icons.people, color: Colors.orange),
            title: Text('Communauté'),
            subtitle: Text('Partage, prie et échange avec d’autres membres.'),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: onPrevious,
                child: const Text('Précédent'),
              ),
              ElevatedButton(
                onPressed: onNext,
                child: const Text('Suivant'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
