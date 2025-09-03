import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emb_mission/core/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LegalPagesScreen extends ConsumerWidget {
  const LegalPagesScreen({super.key});

  // Permet de surcharger le titre du header pour réutiliser le même contenu
  static String? _legalHeaderOverrideTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = ref.watch(userAvatarProvider);
    final isConnected = avatarUrl != null && avatarUrl.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CB6FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Pages Légales',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              radius: 20,
              backgroundImage: isConnected ? NetworkImage(avatarUrl!) : null,
              child: !isConnected
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildLegalItem(
                icon: Icons.shield_outlined,
                iconColor: Colors.blue,
                iconBackground: const Color(0xFFE3F2FD),
                title: 'Politique de Confidentialité',
                subtitle: 'RGPD & Protection des données',
                onTap: () => _showPrivacyPolicyBottomSheet(context),
              ),
              const SizedBox(height: 12),
              _buildLegalItem(
                icon: Icons.description_outlined,
                iconColor: Colors.green,
                iconBackground: const Color(0xFFE8F5E9),
                title: 'Conditions d\'Utilisation',
                subtitle: 'Termes et conditions',
                onTap: () => _showTermsBottomSheet(context),
              ),
              const SizedBox(height: 12),
              _buildLegalItem(
                icon: Icons.info_outline,
                iconColor: Colors.purple,
                iconBackground: const Color(0xFFF3E5F5),
                title: 'À Propos',
                subtitle: 'Version, équipe, contact',
                onTap: () => context.pushNamed('about'),
              ),
              const SizedBox(height: 12),
              _buildLegalItem(
                icon: Icons.help_outline,
                iconColor: Colors.orange,
                iconBackground: const Color(0xFFFFF3E0),
                title: 'Aide & FAQ',
                subtitle: 'Questions fréquentes',
                onTap: () => _showHelpFaqBottomSheet(context),
              ),
              const SizedBox(height: 12),
              _buildLegalItem(
                icon: Icons.warning_amber_outlined,
                iconColor: Colors.red,
                iconBackground: const Color(0xFFFFEBEE),
                title: 'Signaler un Problème',
                subtitle: 'Nous contacter',
                onTap: () => _showReportProblemBottomSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegalItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicyBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LegalPagesScreen._legalHeaderOverrideTitle ?? 'Politique de Confidentialité',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'RGPD & Protection des données',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Politique de confidentialité',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 20),
                          
                          // 1. Informations générales
                          Text(
                            '1. Informations générales',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          
                          Text(
                            'a) Introduction',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 12),
                          
                          Text(
                            'EMB-Mission Inc. accorde une grande importance à la protection de la vie privée.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          
                          Text(
                            'C\'est pourquoi nous avons instauré des mesures de sécurité et des pratiques de gestion responsable de vos informations personnelles, en accord avec les lois en vigueur au Québec et au Canada.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          
                          Text(
                            'Cette politique de confidentialité, qui doit être considérée en conjonction avec nos conditions générales d\'utilisation, détaille nos procédures concernant la collecte, l\'utilisation, le traitement, la communication et la conservation des informations personnelles de nos clients, visiteurs et utilisateurs.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          
                          Text(
                            'En naviguant sur nos sites internet embmission.com, vous consentez à ce que nous collections, utilisions, traitons, divulguons et conservions vos données personnelles en accord avec les termes exposés ci-dessus. Si vous refusez de suivre et d\'être tenu par cette Politique, l\'accès ou l\'utilisation de Nos Sites web ou Nos Services ne vous est pas permis, tout comme le partage de Vos Renseignements personnels avec Nous.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          
                          Text(
                            'Cette Politique n\'inclut pas les informations personnelles des employés, représentants et consultants de l\'Entité, ou toute autre personne associée à l\'Entité, ni toute information qui ne répond pas à la définition d\'information personnelle selon les lois pertinentes du Québec et du Canada. De plus, cette politique ne s\'applique pas à l\'utilisation de notre application, à savoir l\'application EMB-Mission.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 15),
                          
                          // Définitions
                          Text(
                            '« Prestataire de services » :',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 5),
                          
                          Text(
                            'Toute entité, qu\'elle soit physique ou juridique, manipulant des Informations personnelles au nom de l\'Entité.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          
                          Text(
                            'Ces entités tierces ou individuelles sont engagées par l\'Entité afin de faciliter ou fournir les Services, réaliser des prestations en lien avec les Services, ou encore assister l\'Entité dans l\'analyse de l\'utilisation des Services.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 15),
                          
                          Text(
                            '« Politique de gestion et de gouvernance des informations personnelles » :',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 5),
                          
                          Text(
                            'Document qui expose Nos principes régissant la gouvernance de Vos données personnelles. Ces règles établissent, entre autres, les devoirs et les obligations des membres de notre équipe tout au long du cycle de vie de ces informations.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          
                          Text(
                            'Elles contiennent une description de notre procédure de gestion des plaintes concernant la protection de Vos Informations personnelles, une présentation de Nos initiatives d\'éducation et de sensibilisation en matière de protection des données personnelles ainsi que, le cas échéant, les précautions à prendre concernant les informations personnelles utilisées ou utilisées dans le cadre de Nos enquêtes.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 15),
                          
                          Text(
                            '« Données personnelles » :',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 5),
                          
                          Text(
                            'Toute information relative à un individu qui permet de l\'identifier, c\'est-à-dire qui dévoile directement ou indirectement des éléments concernant l\'individu, ses propriétés (par exemple : compétences, goûts, tendances psychologiques, prédispositions, capacités cognitives, personnalité et comportement de la personne en question) ou les actions de cette personne, déterminant du support utilisé et quelle que soit la forme sous laquelle ces données sont présentées (écrite, graphique, sonore, visuelle, informatisée ou autre).',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 15),
                          
                          Text(
                            '« Services » :',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 5),
                          
                          Text(
                            'Englobent les applications présentes sur nos sites web, nos profils sur les réseaux sociaux et tous les programmes et services qui vous y sont proposés, y comprennent.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          
                          Text(
                            'Nos services liés à Notre Entité tels que :',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• Notre chaîne de télévision ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                Text('• Notre outil d\'étude biblique ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                Text('• Nos diffusions audio et podcasts ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                Text('• Nos retransmissions en direct ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                Text('• Nos émissions programmées ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                Text('• Vous donner la possibilité de faire des dons ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                Text('• Inscription pour recevoir des bulletins d\'information ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                Text('• Notre application mobile ; ainsi que', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                Text('• Nos programmes de rediffusion.', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                              ],
                            ),
                          ),
                          SizedBox(height: 15),
                          
                          const Text(
                            '« Sites internet »',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• « Témoin de session » : Les témoins de session sont des documents textuels qui se placent sur votre ordinateur ou votre appareil mobile. Ces cookies peuvent contenir des informations concernant votre historique de navigation, les sites web que vous consultez ainsi que votre navigateur internet.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 24),
                          // 2. Gestion des Informations Personnelles
                          const Text(
                            '2. Gestion des Informations Personnelles',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 16),
                          const Text(
                            '2.1 Rassemblement des informations personnelles',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 12),
                          const Text(
                            'Catégories d\'informations recueillies. Dans le contexte de nos opérations, nous sommes susceptibles de recueillir et manipuler diverses catégories d\'informations personnelles, y compris celles citées ci-après :',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 12),
                          Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• Nous vous demandons de fournir vos informations personnelles, y compris votre nom et prénom, votre adresse, votre adresse e-mail et votre numéro de téléphone, lorsque vous souhaitez vous inscrire aux services qui les requièrent.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Des détails concernant les transactions et le paiement, tels que le moyen de paiement utilisé, la date et l\'heure, le montant du paiement, le code postal de facturation, votre adresse et d\'autres informations pertinentes.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '• Des informations indispensables pour la fourniture de Nos Services, telles que les détails relatifs aux Services que Nous Vous avons fournis ou que Nous Vous avons fourni ;',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '• Les informations que vous décidez de nous transmettre, par exemple, lors de la complétion d\'un formulaire en ligne, d\'un don, de candidature à un poste ou lors de vos échanges avec l\'un de Nos collaborateurs ou représentants.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'L\'acquisition d\'informations peut inclure, entre autres, Votre situation de résidence, Votre niveau d\'éducation, Vos références professionnelles, Votre trajectoire professionnelle, Vos traits personnels, Votre permis de conduire, le pays où vous vivez et Vos compétences ;',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '• Des informations sont obtenues automatiquement lors de l\'exploitation de notre site internet et de nos services, comprenant :',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Padding(
                                  padding: EdgeInsets.only(left: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Des informations concernant les connexions et diverses données relatives à vos actions sur notre site internet, par exemple votre adresse IP, les pages que vous avez visitées, l\'heure et la date de vos visites, le nombre de fois que vous êtes connecté, le navigateur que vous employez, le système d\'exploitation de votre appareil ainsi que d\'autres informations liées au matériel et aux logiciels ;',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                SizedBox(height: 8),
                                      Text(
                                        'Des informations démographiques et de localisation géographique, basées sur votre adresse IP ou la localisation GPS de votre appareil mobile (en fonction des configurations de votre appareil), peuvent être utilisées pour déterminer un emplacement précis ou approximatif. Cette collection est utilisée à des fins techniques, comme par exemple pour déterminer le contenu en direct pertinent selon votre localisation géographique.',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                                SizedBox(height: 8),
                                Text(
                            'Dans chaque situation, ces informations personnelles sont gérées conformément aux objectifs légitimes et indispensables listés à l\'article suivant.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 24),
                          // 3. Utilisation des Informations personnelles
                          const Text(
                            '3. Utilisation des Informations personnelles',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 12),
                          const Text(
                            'Nous pouvons employer vos informations personnelles pour les raisons légitimes mentionnées ci-dessous :',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 12),
                          Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• Assurer le fonctionnement, la maintenance, la supervision, le développement, l\'amélioration et la fourniture de toutes les fonctionnalités de Nos Sites web ;',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '• Vous donner la possibilité de rapporter un souci technique ;',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '• Vous proposez des dons à notre Organisation, ou encore vous fournissez des reçus fiscaux ;',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '• Vous présentez ou Vous fournissez des Services, comprenant Nos services associés à Notre Organisation parmi lesquels :',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Padding(
                                  padding: EdgeInsets.only(left: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '❖ Notre Chaîne de télévision ;',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '❖ Notre Outil d\'étude biblique ;',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '❖ Nos Diffusions audio et podcasts ;',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '❖ Nos Émissions diffusées en direct ;',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '❖ Nos Programmes de rediffusions ;',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '❖ Rassembler vos contributions ;',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '❖ Concevoir, perfectionner et proposer de nouveaux Services ;',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '❖ Vous transmettez des communications, des actualisations, des alertes de sécurité ;',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '❖ Fournir des réponses à vos interrogatoires et une aide si nécessaire ;',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '❖ Recueillir les avis et remarques concernant Nos Services ;',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '❖ Effectuer des études, des analyses et des statistiques en rapport avec Notre Entité et Nos Services ;',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '❖ Dénoncer et prévenir les fraudes, erreurs, spams, abus, incidents de sécurité et autres actes nuisibles ;',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '❖ Pour toute autre nécessité autorisée ou exigée par la loi.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // 3.1 Accord pour l'utilisation des informations personnelles
                          const Text(
                            '3.1 Accord pour l\'utilisation des informations personnelles.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Autant que faisable, l\'Entité sollicite directement le consentement de la personne concernée pour que Nous puissions collecter, utiliser et partager ses Informations personnelles. Cependant, si vous nous transmettez des informations personnelles concernant d\'autres individus, vous devez garantir qu\'ils ont été dûment informés que vous nous partagez leurs informations ainsi que de l\'acquisition de leur consentement pour une telle divulgation.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nous demandons votre consentement explicite, manifeste, libre et informé avant d\'utiliser ou de divulguer vos informations personnelles pour des autres objectifs que ceux précisés dans ce document. Nous demandons également votre accord explicite chaque fois que des informations personnelles sensibles seront concernées dans une des opérations de traitement de l\'Entité.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nous sollicitons votre accord pour chaque objectif particulier de manière simple et explicite, séparément de toute autre information qui pourrait vous être présentée.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'En naviguant sur notre site internet et en fournissant vos informations personnelles par email, vous donnez votre accord pour cette politique de confidentialité ainsi que pour la collecte et le traitement de vos données personnelles conformément à ladite politique.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Si vous n\'acceptez pas, merci de ne plus utiliser ce site web. À moins d\'une disposition légale contraire, vous avez la possibilité de révoquer votre accord à tout moment, en faisant obtenir un avis préalable raisonnable. Il est à noter que si vous décidez de révoquer votre consentement pour la collecte, l\'utilisation ou la divulgation de vos informations personnelles, certaines options sur nos sites web pourraient ne plus être disponibles pour vous, ou nous serons incapables de vous proposer certains de nos services.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // 3.2 Préservation des Informations Personnelles
                          const Text(
                            '3.2 Préservation des Informations Personnelles.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Conformément aux lois en vigueur, nous ne gardons Vos Renseignements personnels que le temps nécessaire à l\'accomplissement des objectifs pour lesquels ces informations ont été recueillies, sauf si vous donnez votre accord pour une autre utilisation ou traitement de Vos Renseignements personnels. De plus, nos durées de conservation peuvent être prolongées au besoin en fonction d\'intérêts légitimes (par exemple, pour assurer la sécurité des données personnelles, prévenir les abus et infractions ou pour prolonger des criminels).',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Pour toute information supplémentaire concernant la durée de conservation de Vos Renseignements personnels, n\'hésitez pas à prendre contact avec notre Responsable de la protection des données.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Pour obtenir des informations personnelles, utilisez les coordonnées décrites à l\'article 1b) de cette Politique.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // 4. Vos droits
                          const Text(
                            '4. Vos droits.',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'En tant qu\'individu concerné, vous pouvez faire usage des droits mentionnés ci-dessous en contactant notre Responsable de la protection des données personnelles à l\'adresse fournie à l\'article 1b) de notre Politique. Il est à noter que nous vous demanderons de confirmer votre identité avant de répondre à l\'une ou l\'autre de ces requêtes.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• Vous êtes en droit d\'être renseigné sur les Données personnelles que Nous avons à Votre disposition, leur utilisation, transmission, conservation et élimination, sauf si la loi applicable prévoit des exceptions ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('• Vous avez le droit d\'accéder à vos informations personnelles, de demander une copie, y compris en format papier des documents contenant vos données personnelles, sous réserve des exceptions prévues par la législation en vigueur et d\'obtenir, le cas échéant, des précisions supplémentaires concernant la manière dont nous les utilisons, les partageons, les conservons et les détruisons ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('• Vous avez le droit de corriger, modifier et mettre à jour vos informations personnelles que nous possédons si elles sont incomplètes, ambiguës, périmées ou incorrectes ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('• Vous avez le droit de retirer ou de modifier votre consentement à ce que l\'entité collecte, utilise, partage ou conserve vos informations personnelles à tout moment, sous réserve des restrictions légales et contractuelles pertinentes ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('• Vous êtes en droit de nous solliciter pour arrêter la diffusion de vos informations personnelles et d\'effacer tout lien associé à votre nom donnant accès à ces données si cela enfreint la loi ou une décision judiciaire ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('• Vous pouvez également demander que l\'on vous communique vos informations personnelles ou qu\'elles soient transférées vers une autre entité dans un format technologique structuré et fréquemment utilisé ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('• Il est également important de souligner que vous avez le droit d\'être informé d\'un événement de confidentialité touchant à vos informations personnelles qui pourrait vous porter un préjudice grave.', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('Nous maintenons un registre à cet égard qui consigne tous les incidents liés à la confidentialité et nous jugeons les dommages potentiels qu\'ils peuvent engendrer.', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('• Vous êtes en droit de déposer une réclamation auprès de la Commission d\'accès à l\'information, conformément aux conditions stipulées par la loi en vigueur. Pour répondre à votre requête, vous pourriez demander de présenter un justificatif d\'identité adéquat ou de procéder à une autre forme d\'identification.', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // 5. Cookies de connexion et autres technologies de traçage
                          const Text(
                            '5. Cookies de connexion et autres technologies de traçage.',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nous ne faisons pas appel à des cookies ou à d\'autres technologies similaires (collectivement, les « Cookies ») pour nous aider à gérer, sécuriser et améliorer nos sites web et les services que nous proposons.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Les Cookies, ou Fichiers Témoins, sont des petits fichiers de texte qui se récupèrent sur Votre appareil ou dans Votre navigateur.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ils facilitent la collecte de certaines informations lors de votre passage sur nos sites web, y compris votre langue préférée, le type et la version de votre navigateur, le genre d\'appareil que vous employez ainsi que l\'identifiant spécifique de votre appareil.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Si quelques-uns des fichiers témoins « Cookies » que nous employons sont effacés à la clôture de votre session, d\'autres sont maintenus sur votre dispositif ou navigateur pour nous permettre d\'identifier votre navigateur lors de vos futures visites sur nos sites web.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'L\'objectif des informations recueillies via ces Cookies n\'est pas de vous identifier. Ils nous permettent surtout d\'assurer le bon fonctionnement de notre site web, d\'optimiser l\'expérience des utilisateurs et de fournir des informations qui nous permettent de mieux appréhender le trafic et les interactions sur notre site web, ainsi qu\'à identifier certaines formes de fraudes.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Les Cookies ne portent aucun préjudice à votre appareil et ne peuvent être exploités pour obtenir vos informations privées.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nous employons des cookies et d\'autres technologies analogues (collectivement appelées « Cookies ») afin de nous assister dans l\'exploitation, la sécurisation et l\'amélioration de Nos Sites web ainsi que les Services que nous proposons.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Les Cookies, ou Fichiers Témoins, sont des petits fichiers de texte qui se récupèrent sur Votre appareil ou dans Votre navigateur. Ils ont pour vocation de collecter des informations spécifiques lors de votre navigation sur nos sites web, telles que votre langue préférée, le type et la version de l\'appareil que vous utilisez, ainsi que l\'identifiant unique associé à votre appareil.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Si certains des fichiers témoins « Cookies » que nous utilisons sont effacés après la session de votre navigateur, d\'autres sont conservés sur votre appareil ou sur votre navigateur pour nous permettre d\'identifier celui-ci lors de votre prochaine visite sur nos sites web. L\'objectif des informations personnelles recueillies via ces « Cookies » n\'est pas de vous identifier. Ils assurent notamment le bon fonctionnement de Nos Sites web, optimisent l\'expérience de navigation des utilisateurs et nous fournissons certaines informations pour mieux appréhender le trafic et les interactions sur Nos Sites web, tout en permettant d\'identifier certaines formes de fraudes.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Les Cookies, également appelés Fichiers Témoins, ne nuisent en rien à votre appareil et il est impossible de les utiliser pour obtenir vos informations personnelles.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nous collectons Votre adresse IP, les détails concernant Votre appareil, Votre système d\'exploitation ou navigateur, le parcours que Vous effectuez sur Nos Sites web ainsi que l\'historique de Vos navigations, Vos demandes et Vos préférences de navigation (les langues employées), etc.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Il est possible de paramétrer votre navigateur afin d\'être alerté lors de l\'utilisation de Cookies sur nos sites web, ce qui vous permettra de choisir, pour chaque instance, d\'accepter ou de rejeter l\'utilisation de certains ou de tous les Cookies.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Il faut être conscient que la désactivation des Cookies sur votre navigateur pourrait dégrader votre expérience de navigation sur nos sites et vous priver de certaines de leurs fonctions.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Pour approfondir votre compréhension de notre utilisation des « Cookies », veuillez-vous référer à notre « Politique relative aux cookies ».',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // 6. Dispositions de sécurité
                          const Text(
                            '6. Dispositions de sécurité.',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'L\'Entité a instauré des dispositifs de sécurité physiques, technologiques et organisationnels afin de sauvegarder correctement la confidentialité et la sécurité de Vos informations personnelles face à toute perte, vol ou accès, divulgation, reproduction, communication, utilisation ou modification non autorisée. Ces actions incluent spécifiquement :',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'D\'un point de vue administratif, la mise en œuvre d\'une série de politiques et procédures dans le contexte de l\'établissement de notre programme de gouvernance de l\'information qui comprend notamment :',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ils régulent l\'accès, la communication, la conservation, la dépersonnalisation, y comprennent l\'anonymisation et/ou, si nécessaire, la destruction des Informations personnelles ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('• ils assument les rôles et responsabilités de Nos employés tout au long du cycle de vie des Informations personnelles et documents ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('• ils instaurent les procédures d\'intervention et de réponse lors d\'un incident de confidentialité ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('• ils gèrent le processus des demandes et réclamations concernant la protection et le traitement des Informations personnelles.', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'D\'un point de vue technique, on fait appel à différents outils comme :',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('– l\'emploi de serveurs protégés. Toutes les données confidentielles que vous avez fournies sont envoyées par le biais de la technologie « Secure Socket Layer (SSL) ».', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('• L\'emploi de dispositifs de sauvegarde, de programmes de supervision du réseau, etc. ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('• Le recours à un système de cryptage pour les informations délicates ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                SizedBox(height: 8),
                                Text('• La mise en place d\'un mécanisme de division des fonctions et des contrôles d\'accès ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nous réalisons des vérifications internes chaque mois pour assurer la sécurité de nos serveurs.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Du fait du caractère public de cette Politique, nous n\'avons pas détaillé l\'intégralité des mesures que nous instaurons.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Bien que nous ayons mis en place les mesures mentionnées précédemment, nous ne sommes pas en mesure de garantir une sécurité totale pour vos informations personnelles.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Si vous pensez que la sécurité de Vos Informations personnelles n\'est plus garantie, veuillez prendre contact sans délai avec Notre Responsable de la protection des informations personnelles en utilisant les coordonnées mentionnées à l\'article 1b) ci-dessus.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // 7. Modification de cette Politique de confidentialité
                          const Text(
                            '7. Modification de cette Politique de confidentialité.',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nous nous accordons le droit d\'ajuster cette politique à tout moment en respectant les lois en vigueur. Si des modifications sont proposées, nous mettrons à jour la Politique de confidentialité et changerons la date de mise à jour indiquée en bas de page.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Si vous n\'adhérez pas aux nouvelles stipulations de notre Politique de confidentialité, nous vous recommandons de cesser l\'utilisation de Nos Sites web et Nos Services.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Si vous persistez à utiliser Nos Sites web ou Nos Services après la mise en application de la nouvelle version de notre Politique, Votre recours à Nos Sites web et Nos Services sera alors soumis à cette nouvelle version de la Politique.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // 8. Personnes de moins de 14 ans
                          const Text(
                            '8. Personnes de moins de 14 ans.',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nous ne collectons ni n\'utilisons intentionnellement des informations personnelles de mineurs de moins de 14 ans. Si vous êtes âgé de moins de 14 ans, il est interdit de nous communiquer vos informations personnelles sans l\'accord de vos parents ou de votre tuteur. Dans le cas où vous seriez un parent ou tuteur et que vous découvrez que votre enfant nous a transmis des informations personnelles sans autorisation, veuillez nous joindre en utilisant les coordonnées mentionnées à l\'article 1b) ci-dessus pour solliciter la suppression des données personnelles de cet enfant de nos systèmes.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // 9. Règlements en vigueur
                          const Text(
                            '9. Règlements en vigueur.',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Cet accord et votre utilisation de nos sites web seront régis par les lois du Canada et du Québec, à l\'exception de leurs règles de conflits de droit. L\'utilisation de Nos Sites web peut également être soumise à d\'autres lois locales, régionales, nationales ou internationales.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTermsBottomSheet(BuildContext context) {
    // Réutilise le même contenu mais change le titre
    LegalPagesScreen._legalHeaderOverrideTitle = "Conditions d'Utilisation";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Appelle le même contenu
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            // On reconstruit en appelant la même méthode pour garder le contenu identique
            // en laissant le header utiliser le titre surchargé
            return Builder(
              builder: (_) {
                // Hack simple: on réutilise la méthode existante qui construit le même contenu
                // en appelant directement la fonction de privacy
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Rien, juste pour garder la structure
                });
                // Duplique la structure de _showPrivacyPolicyBottomSheet en faisant un appel direct
                // en profitant des mêmes widgets.
                // Pour éviter la duplication massive, on appelle la fonction existante
                // en ouvrant un autre BottomSheet serait gênant; à la place on copie minimalement la structure
                // ici, on appelle la même construction que _showPrivacyPolicyBottomSheet
                // en reprenant son Container (copié ci-dessous):
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.description_outlined,
                                color: Colors.green,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    // Utilise le titre surchargé
                                    'Conditions d\'Utilisation',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Termes et conditions',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      // Contenu des Conditions d'Utilisation
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 20),
                              Text(
                                'Conditions d\'Utilisation',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 20),
                              // 1. Informations générales
                              Text(
                                '1. Informations générales',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'a) Introduction',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'EMB-Mission Inc. accorde une grande importance à la protection de la vie privée.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'C\'est pourquoi nous avons instauré des mesures de sécurité et des pratiques de gestion responsable de vos informations personnelles, en accord avec les lois en vigueur au Québec et au Canada.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Cette politique de confidentialité, qui doit être considérée en conjonction avec nos conditions générales d\'utilisation, détaille nos procédures concernant la collecte, l\'utilisation, le traitement, la communication et la conservation des informations personnelles de nos clients, visiteurs et utilisateurs.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'En naviguant sur nos sites internet embmission.com, vous consentez à ce que nous collectons, utilisons, traitons, divulguons et conservons vos données personnelles en accord avec les termes exposés ci-dessus. Si vous refusez de suivre et d\'être tenu par cette Politique, l\'accès ou l\'utilisation de Nos Sites web ou Nos Services ne vous est pas permis, tout comme le partage de Vos Renseignements personnels avec Nous.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Cette Politique n\'inclut pas les informations personnelles des employés, représentants et consultants de l\'Entité, ou toute autre personne associée à l\'Entité, ni toute information qui ne répond pas à la définition d\'information personnelle selon les lois pertinentes du Québec et du Canada. De plus, cette politique ne s\'applique pas à l\'utilisation de notre application, à savoir l\'application EMB-Mission.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '« Prestataire de services » :',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Toute entité, qu\'elle soit physique ou juridique, manipulant des Informations personnelles au nom de l\'Entité.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Ces entités tierces ou individuelles sont engagées par l\'Entité afin de faciliter ou fournir les Services, réaliser des prestations en lien avec les Services, ou encore assister l\'Entité dans l\'analyse de l\'utilisation des Services.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '« Politique de gestion et de gouvernance des informations personnelles » :',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Document qui expose Nos principes régissant la gouvernance de Vos données personnelles. Ces règles établissent, entre autres, les devoirs et les obligations des membres de notre équipe tout au long du cycle de vie de ces informations.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Elles contiennent une description de notre procédure de gestion des plaintes concernant la protection de Vos Informations personnelles, une présentation de Nos initiatives d\'éducation et de sensibilisation en matière de protection des données personnelles ainsi que, le cas échéant, les précautions à prendre concernant les informations personnelles utilisées ou utilisées dans le cadre de Nos enquêtes.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '« Données personnelles » :',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Toute information relative à un individu qui permet de l\'identifier, c\'est-à-dire qui dévoile directement ou indirectement des éléments concernant l\'individu, ses propriétés (par exemple : compétences, goûts, tendances psychologiques, prédispositions, capacités cognitives, personnalité et comportement de la personne en question) ou les actions de cette personne, déterminant du support utilisé et quelle que soit la forme sous laquelle ces données sont présentées (écrite, graphique, sonore, visuelle, informatisée ou autre).',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '« Services » :',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Englobent les applications présentes sur nos sites web, nos profils sur les réseaux sociaux et tous les programmes et services qui vous y sont proposés, y comprennent.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Nos services liés à Notre Entité tels que :',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Padding(
                                padding: EdgeInsets.only(left: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• Notre chaîne de télévision ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '• Notre outil d\'étude biblique ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '• Nos diffusions audio et podcasts ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '• Nos retransmissions en direct ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '• Nos émissions programmées ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '• Vous donner la possibilité de faire des dons ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '• Inscription pour recevoir des bulletins d\'information ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '• Notre application mobile ; ainsi que',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '• Nos programmes de rediffusion.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '« Sites internet »',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '• « Témoin de session » : Les témoins de session sont des documents textuels qui se placent sur votre ordinateur ou votre appareil mobile. Ces cookies peuvent contenir des informations concernant votre historique de navigation, les sites web que vous consultez ainsi que votre navigateur internet.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 24),
                              // 2. Gestion des Informations Personnelles
                              Text(
                                '2. Gestion des Informations Personnelles',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '2.1 Rassemblement des informations personnelles',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Catégories d\'informations recueillies. Dans le contexte de nos opérations, nous sommes susceptibles de recueillir et manipuler diverses catégories d\'informations personnelles, y compris celles citées ci-après :',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 12),
                              Padding(
                                padding: EdgeInsets.only(left: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• Nous vous demandons de fournir vos informations personnelles, y compris votre nom et prénom, votre adresse, votre adresse e-mail et votre numéro de téléphone, lorsque vous souhaitez vous inscrire aux services qui les requièrent.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Des détails concernant les transactions et le paiement, tels que le moyen de paiement utilisé, la date et l\'heure, le montant du paiement, le code postal de facturation, votre adresse et d\'autres informations pertinentes.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '• Des informations indispensables pour la fourniture de Nos Services, telles que les détails relatifs aux Services que Nous Vous avons fournis ou que Nous Vous avons fourni ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '• Les informations que vous décidez de nous transmettre, par exemple, lors de la complétion d\'un formulaire en ligne, d\'un don, de candidature à un poste ou lors de vos échanges avec l\'un de Nos collaborateurs ou représentants.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'L\'acquisition d\'informations peut inclure, entre autres, Votre situation de résidence, Votre niveau d\'éducation, Vos références professionnelles, Votre trajectoire professionnelle, Vos traits personnels, Votre permis de conduire, le pays où vous vivez et Vos compétences ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '• Des informations sont obtenues automatiquement lors de l\'exploitation de notre site internet et de nos services, comprenant :',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Padding(
                                      padding: EdgeInsets.only(left: 20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Des informations concernant les connexions et diverses données relatives à vos actions sur notre site internet, par exemple votre adresse IP, les pages que vous avez visitées, l\'heure et la date de vos visites, le nombre de fois que vous êtes connecté, le navigateur que vous employez, le système d\'exploitation de votre appareil ainsi que d\'autres informations liées au matériel et aux logiciels ;',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Des informations démographiques et de localisation géographique, basées sur votre adresse IP ou la localisation GPS de votre appareil mobile (en fonction des configurations de votre appareil), peuvent être utilisées pour déterminer un emplacement précis ou approximatif. Cette collection est utilisée à des fins techniques, comme par exemple pour déterminer le contenu en direct pertinent selon votre localisation géographique.',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Dans chaque situation, ces informations personnelles sont gérées conformément aux objectifs légitimes et indispensables listés à l\'article suivant.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              // 3. Utilisation des Informations personnelles
                              Text(
                                '3. Utilisation des Informations personnelles',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Nous pouvons employer vos informations personnelles pour les raisons légitimes mentionnées ci-dessous :',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 12),
                              Padding(
                                padding: EdgeInsets.only(left: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• Assurer le fonctionnement, la maintenance, la supervision, le développement, l\'amélioration et la fourniture de toutes les fonctionnalités de Nos Sites web ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '• Vous donner la possibilité de rapporter un souci technique ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '• Vous proposez des dons à notre Organisation, ou encore vous fournissez des reçus fiscaux ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '• Vous présentez ou Vous fournissez des Services, comprenant Nos services associés à Notre Organisation parmi lesquels :',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Padding(
                                      padding: EdgeInsets.only(left: 20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '❖ Notre Chaîne de télévision ;',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '❖ Notre Outil d\'étude biblique ;',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '❖ Nos Diffusions audio et podcasts ;',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '❖ Nos Émissions diffusées en direct ;',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '❖ Nos Programmes de rediffusions ;',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '❖ Rassembler vos contributions ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '❖ Concevoir, perfectionner et proposer de nouveaux Services ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '❖ Vous transmettez des communications, des actualisations, des alertes de sécurité ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '❖ Fournir des réponses à vos interrogatoires et une aide si nécessaire ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '❖ Recueillir les avis et remarques concernant Nos Services ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '❖ Effectuer des études, des analyses et des statistiques en rapport avec Notre Entité et Nos Services ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '❖ Dénoncer et prévenir les fraudes, erreurs, spams, abus, incidents de sécurité et autres actes nuisibles ;',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '❖ Pour toute autre nécessité autorisée ou exigée par la loi.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // 3.1 Accord pour l'utilisation des informations personnelles
                              const Text(
                                '3.1 Accord pour l\'utilisation des informations personnelles.',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Autant que faisable, l\'Entité sollicite directement le consentement de la personne concernée pour que Nous puissions collecter, utiliser et partager ses Informations personnelles. Cependant, si vous nous transmettez des informations personnelles concernant d\'autres individus, vous devez garantir qu\'ils ont été dûment informés que vous nous partagez leurs informations ainsi que de l\'acquisition de leur consentement pour une telle divulgation.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Nous demandons votre consentement explicite, manifeste, libre et informé avant d\'utiliser ou de divulguer vos informations personnelles pour des autres objectifs que ceux précisés dans ce document. Nous demandons également votre accord explicite chaque fois que des informations personnelles sensibles seront concernées dans une des opérations de traitement de l\'Entité.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Nous sollicitons votre accord pour chaque objectif particulier de manière simple et explicite, séparément de toute autre information qui pourrait vous être présentée.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'En naviguant sur notre site internet et en fournissant vos informations personnelles par email, vous donnez votre accord pour cette politique de confidentialité ainsi que pour la collecte et le traitement de vos données personnelles conformément à ladite politique.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Si vous n\'acceptez pas, merci de ne plus utiliser ce site web. À moins d\'une disposition légale contraire, vous avez la possibilité de révoquer votre accord à tout moment, en faisant obtenir un avis préalable raisonnable. Il est à noter que si vous décidez de révoquer votre consentement pour la collecte, l\'utilisation ou la divulgation de vos informations personnelles, certaines options sur nos sites web pourraient ne plus être disponibles pour vous, ou nous serons incapables de vous proposer certains de nos services.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // 3.2 Préservation des Informations Personnelles
                              const Text(
                                '3.2 Préservation des Informations Personnelles.',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Conformément aux lois en vigueur, nous ne gardons Vos Renseignements personnels que le temps nécessaire à l\'accomplissement des objectifs pour lesquels ces informations ont été recueillies, sauf si vous donnez votre accord pour une autre utilisation ou traitement de Vos Renseignements personnels. De plus, nos durées de conservation peuvent être prolongées au besoin en fonction d\'intérêts légitimes (par exemple, pour assurer la sécurité des données personnelles, prévenir les abus et infractions ou pour prolonger des criminels).',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Pour toute information supplémentaire concernant la durée de conservation de Vos Renseignements personnels, n\'hésitez pas à prendre contact avec notre Responsable de la protection des données.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Pour obtenir des informations personnelles, utilisez les coordonnées décrites à l\'article 1b) de cette Politique.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // 4. Vos droits
                              const Text(
                                '4. Vos droits.',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'En tant qu\'individu concerné, vous pouvez faire usage des droits mentionnés ci-dessous en contactant notre Responsable de la protection des données personnelles à l\'adresse fournie à l\'article 1b) de notre Politique. Il est à noter que nous vous demanderons de confirmer votre identité avant de répondre à l\'une ou l\'autre de ces requêtes.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Padding(
                                padding: EdgeInsets.only(left: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('• Vous êtes en droit d\'être renseigné sur les Données personnelles que Nous avons à Votre disposition, leur utilisation, transmission, conservation et élimination, sauf si la loi applicable prévoit des exceptions ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('• Vous avez le droit d\'accéder à vos informations personnelles, de demander une copie, y compris en format papier des documents contenant vos données personnelles, sous réserve des exceptions prévues par la législation en vigueur et d\'obtenir, le cas échéant, des précisions supplémentaires concernant la manière dont nous les utilisons, les partageons, les conservons et les détruisons ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('• Vous avez le droit de corriger, modifier et mettre à jour vos informations personnelles que nous possédons si elles sont incomplètes, ambiguës, périmées ou incorrectes ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('• Vous avez le droit de retirer ou de modifier votre consentement à ce que l\'entité collecte, utilise, partage ou conserve vos informations personnelles à tout moment, sous réserve des restrictions légales et contractuelles pertinentes ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('• Vous êtes en droit de nous solliciter pour arrêter la diffusion de vos informations personnelles et d\'effacer tout lien associé à votre nom donnant accès à ces données si cela enfreint la loi ou une décision judiciaire ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('• Vous pouvez également demander que l\'on vous communique vos informations personnelles ou qu\'elles soient transférées vers une autre entité dans un format technologique structuré et fréquemment utilisé ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('• Il est également important de souligner que vous avez le droit d\'être informé d\'un événement de confidentialité touchant à vos informations personnelles qui pourrait vous porter un préjudice grave.', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('Nous maintenons un registre à cet égard qui consigne tous les incidents liés à la confidentialité et nous jugeons les dommages potentiels qu\'ils peuvent engendrer.', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('• Vous êtes en droit de déposer une réclamation auprès de la Commission d\'accès à l\'information, conformément aux conditions stipulées par la loi en vigueur. Pour répondre à votre requête, vous pourriez demander de présenter un justificatif d\'identité adéquat ou de procéder à une autre forme d\'identification.', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // 5. Cookies de connexion et autres technologies de traçage
                              const Text(
                                '5. Cookies de connexion et autres technologies de traçage.',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Nous ne faisons pas appel à des cookies ou à d\'autres technologies similaires (collectivement, les « Cookies ») pour nous aider à gérer, sécuriser et améliorer nos sites web et les services que nous proposons.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Les Cookies, ou Fichiers Témoins, sont des petits fichiers de texte qui se récupèrent sur Votre appareil ou dans Votre navigateur.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Ils facilitent la collecte de certaines informations lors de votre passage sur nos sites web, y compris votre langue préférée, le type et la version de votre navigateur, le genre d\'appareil que vous employez ainsi que l\'identifiant spécifique de votre appareil.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Si quelques-uns des fichiers témoins « Cookies » que nous employons sont effacés à la clôture de votre session, d\'autres sont maintenus sur votre dispositif ou navigateur pour nous permettre d\'identifier votre navigateur lors de vos futures visites sur nos sites web.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'L\'objectif des informations recueillies via ces Cookies n\'est pas de vous identifier. Ils nous permettent surtout d\'assurer le bon fonctionnement de notre site web, d\'optimiser l\'expérience des utilisateurs et de fournir des informations qui nous permettent de mieux appréhender le trafic et les interactions sur notre site web, ainsi qu\'à identifier certaines formes de fraudes.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Les Cookies ne portent aucun préjudice à votre appareil et ne peuvent être exploités pour obtenir vos informations privées.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Nous employons des cookies et d\'autres technologies analogues (collectivement appelées « Cookies ») afin de nous assister dans l\'exploitation, la sécurisation et l\'amélioration de Nos Sites web ainsi que les Services que nous proposons.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Les Cookies, ou Fichiers Témoins, sont des petits fichiers de texte qui se récupèrent sur Votre appareil ou dans Votre navigateur. Ils ont pour vocation de collecter des informations spécifiques lors de votre navigation sur nos sites web, telles que votre langue préférée, le type et la version de l\'appareil que vous utilisez, ainsi que l\'identifiant unique associé à votre appareil.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Si certains des fichiers témoins « Cookies » que nous utilisons sont effacés après la session de votre navigateur, d\'autres sont conservés sur votre appareil ou sur votre navigateur pour nous permettre d\'identifier celui-ci lors de votre prochaine visite sur nos sites web. L\'objectif des informations personnelles recueillies via ces « Cookies » n\'est pas de vous identifier. Ils assurent notamment le bon fonctionnement de Nos Sites web, optimisent l\'expérience de navigation des utilisateurs et nous fournissons certaines informations pour mieux appréhender le trafic et les interactions sur Nos Sites web, tout en permettant d\'identifier certaines formes de fraudes.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Les Cookies, également appelés Fichiers Témoins, ne nuisent en rien à votre appareil et il est impossible de les utiliser pour obtenir vos informations personnelles.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Nous collectons Votre adresse IP, les détails concernant Votre appareil, Votre système d\'exploitation ou navigateur, le parcours que Vous effectuez sur Nos Sites web ainsi que l\'historique de Vos navigations, Vos demandes et Vos préférences de navigation (les langues employées), etc.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Il est possible de paramétrer votre navigateur afin d\'être alerté lors de l\'utilisation de Cookies sur nos sites web, ce qui vous permettra de choisir, pour chaque instance, d\'accepter ou de rejeter l\'utilisation de certains ou de tous les Cookies.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Il faut être conscient que la désactivation des Cookies sur votre navigateur pourrait dégrader votre expérience de navigation sur nos sites et vous priver de certaines de leurs fonctions.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Pour approfondir votre compréhension de notre utilisation des « Cookies », veuillez-vous référer à notre « Politique relative aux cookies ».',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // 6. Dispositions de sécurité
                              const Text(
                                '6. Dispositions de sécurité.',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'L\'Entité a instauré des dispositifs de sécurité physiques, technologiques et organisationnels afin de sauvegarder correctement la confidentialité et la sécurité de Vos informations personnelles face à toute perte, vol ou accès, divulgation, reproduction, communication, utilisation ou modification non autorisée. Ces actions incluent spécifiquement :',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'D\'un point de vue administratif, la mise en œuvre d\'une série de politiques et procédures dans le contexte de l\'établissement de notre programme de gouvernance de l\'information qui comprend notamment :',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Padding(
                                padding: EdgeInsets.only(left: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('• ils régulent l\'accès, la communication, la conservation, la dépersonnalisation, y comprennent l\'anonymisation et/ou, si nécessaire, la destruction des Informations personnelles ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('• ils assument les rôles et responsabilités de Nos employés tout au long du cycle de vie des Informations personnelles et documents ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('• ils instaurent les procédures d\'intervention et de réponse lors d\'un incident de confidentialité ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('• ils gèrent le processus des demandes et réclamations concernant la protection et le traitement des Informations personnelles.', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'D\'un point de vue technique, on fait appel à différents outils comme :',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Padding(
                                padding: EdgeInsets.only(left: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('– l\'emploi de serveurs protégés. Toutes les données confidentielles que vous avez fournies sont envoyées par le biais de la technologie « Secure Socket Layer (SSL) ».', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('• L\'emploi de dispositifs de sauvegarde, de programmes de supervision du réseau, etc. ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('• Le recours à un système de cryptage pour les informations délicates ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                    SizedBox(height: 8),
                                    Text('• La mise en place d\'un mécanisme de division des fonctions et des contrôles d\'accès ;', style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Nous réalisons des vérifications internes chaque mois pour assurer la sécurité de nos serveurs.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Du fait du caractère public de cette Politique, nous n\'avons pas détaillé l\'intégralité des mesures que nous instaurons.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Bien que nous ayons mis en place les mesures mentionnées précédemment, nous ne sommes pas en mesure de garantir une sécurité totale pour vos informations personnelles.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Si vous pensez que la sécurité de Vos Informations personnelles n\'est plus garantie, veuillez prendre contact sans délai avec Notre Responsable de la protection des informations personnelles en utilisant les coordonnées mentionnées à l\'article 1b) ci-dessus.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // 7. Modification de cette Politique de confidentialité
                              const Text(
                                '7. Modification de cette Politique de confidentialité.',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Nous nous accordons le droit d\'ajuster cette politique à tout moment en respectant les lois en vigueur. Si des modifications sont proposées, nous mettrons à jour la Politique de confidentialité et changerons la date de mise à jour indiquée en bas de page.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Si vous n\'adhérez pas aux nouvelles stipulations de notre Politique de confidentialité, nous vous recommandons de cesser l\'utilisation de Nos Sites web et Nos Services.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Si vous persistez à utiliser Nos Sites web ou Nos Services après la mise en application de la nouvelle version de notre Politique, Votre recours à Nos Sites web et Nos Services sera alors soumis à cette nouvelle version de la Politique.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // 8. Personnes de moins de 14 ans
                              const Text(
                                '8. Personnes de moins de 14 ans.',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Nous ne collectons ni n\'utilisons intentionnellement des informations personnelles de mineurs de moins de 14 ans. Si vous êtes âgé de moins de 14 ans, il est interdit de nous communiquer vos informations personnelles sans l\'accord de vos parents ou de votre tuteur. Dans le cas où vous seriez un parent ou tuteur et que vous découvrez que votre enfant nous a transmis des informations personnelles sans autorisation, veuillez nous joindre en utilisant les coordonnées mentionnées à l\'article 1b) ci-dessus pour solliciter la suppression des données personnelles de cet enfant de nos systèmes.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // 9. Règlements en vigueur
                              const Text(
                                '9. Règlements en vigueur.',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Cet accord et votre utilisation de nos sites web seront régis par les lois du Canada et du Québec, à l\'exception de leurs règles de conflits de droit. L\'utilisation de Nos Sites web peut également être soumise à d\'autres lois locales, régionales, nationales ou internationales.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showHelpFaqBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.help_outline,
                            color: Colors.orange,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aide & FAQ',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Questions fréquentes',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  // Content — FAQ fourni
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FAQ – EMB MISSION', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          SizedBox(height: 16),

                          Text('1. Comment écouter la Web Radio ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('Ouvrez l\'onglet Radio dans l\'application, puis cliquez sur Lecture. Assurez-vous que votre connexion internet est active.'),
                          Divider(height: 24),

                          Text('2. Comment regarder la Web TV ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('Allez dans l\'onglet TV et appuyez sur Lecture. La vidéo se lancera automatiquement.'),
                          SizedBox(height: 4),
                          Text('💡 Si la vidéo ne démarre pas, vérifiez votre connexion Wi-Fi ou 4G.', style: TextStyle(color: Colors.grey)),
                          Divider(height: 24),

                          Text('3. Puis-je écouter la radio ou regarder la TV en arrière-plan ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('Oui, la Web Radio fonctionne en arrière-plan. Pour la Web TV, l\'audio peut continuer si l\'écran est verrouillé (selon les réglages de votre appareil).'),
                          Divider(height: 24),

                          Text('4. L\'audio ou la vidéo ne se lance pas, que faire ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('• Fermez l\'application et relancez-la.\n• Vérifiez votre connexion internet.\n• Si le problème persiste, contactez-nous via Assistance dans le menu.'),
                          Divider(height: 24),

                          Text('5. Comment signaler un problème technique ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('Rendez-vous dans Menu → Assistance, puis remplissez le formulaire avec la description du problème et votre modèle de téléphone.'),
                          Divider(height: 24),

                          Text('6. Comment mettre à jour l\'application ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('Ouvrez le Store de votre appareil (Google Play, App Store, etc.), recherchez EMB MISSION et cliquez sur Mettre à jour.'),
                          Divider(height: 24),

                          Text('7. Les vidéos ou la radio consomment-elles beaucoup de données ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('Oui, la lecture en streaming utilise des données. Pour réduire la consommation, utilisez une connexion Wi-Fi.'),
                          Divider(height: 24),

                          Text('8. L\'application est-elle gratuite ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('Oui, toutes les fonctionnalités actuelles sont accessibles gratuitement.'),
                          Divider(height: 24),

                          Text('9. Puis-je utiliser l\'application sur plusieurs appareils ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('Oui, vous pouvez installer et utiliser l\'application sur tous vos appareils compatibles.'),
                          Divider(height: 24),

                          Text('10. Comment contacter le support technique ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('Depuis Menu → Assistance, ou par email : support@embmission.com.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showReportProblemBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            final formKey = GlobalKey<FormState>();
            final nameController = TextEditingController();
            final subjectController = TextEditingController();
            final messageController = TextEditingController();
            final emailController = TextEditingController();
            bool isSending = false;
            return StatefulBuilder(
              builder: (context, setState) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.warning_amber_outlined, color: Colors.red, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Signaler un problème', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  Text('Décrivez brièvement le souci rencontré', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      // Form
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Votre nom',
                                    hintText: 'ex: Jean Dupont',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Adresse e-mail',
                                    hintText: 'ex: nom@domaine.com',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'E-mail requis';
                                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
                                    if (!ok) return 'E-mail invalide';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: subjectController,
                                  decoration: const InputDecoration(
                                    labelText: 'Sujet',
                                    hintText: 'Titre du problème',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Sujet requis' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: messageController,
                                  minLines: 5,
                                  maxLines: 10,
                                  decoration: const InputDecoration(
                                    labelText: 'Message',
                                    hintText: 'Décrivez votre problème…',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Message requis' : null,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('Annuler'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: isSending
                                            ? null
                                            : () async {
                                                if (!formKey.currentState!.validate()) return;
                                                setState(() => isSending = true);
                                                final uri = Uri.parse('https://embmission.com/mobileappebm/api/problemesignaler_embmission');
                                                final payload = {
                                                  'name': nameController.text.trim(),
                                                  'email': emailController.text.trim(),
                                                  'sujet': subjectController.text.trim(),
                                                  'message': messageController.text.trim(),
                                                };
                                                try {
                                                  final resp = await http
                                                      .post(
                                                        uri,
                                                        headers: {'Content-Type': 'application/json'},
                                                        body: jsonEncode(payload),
                                                      )
                                                      .timeout(const Duration(seconds: 20));
                                                  if (resp.statusCode == 200) {
                                                    final data = jsonDecode(resp.body);
                                                    final ok = (data['statutmail'] == 'success');
                                                    if (ok) {
                                                      if (context.mounted) {
                                                        Navigator.of(context).pop();
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Message envoyé avec succès')),
                                                        );
                                                      }
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Échec de l\'envoi: ${data['statutmail'] ?? 'inconnu'}')),
                                                      );
                                                    }
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Erreur réseau: ${resp.statusCode}')),
                                                    );
                                                  }
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Erreur: $e')),
                                                  );
                                                } finally {
                                                  setState(() => isSending = false);
                                                }
                                              },
                                        child: isSending
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Text('Envoyer'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
