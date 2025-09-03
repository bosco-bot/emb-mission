import 'package:flutter/material.dart';
import 'package:emb_mission/core/models/content_item.dart';
import 'package:emb_mission/core/theme/app_theme.dart';

/// Widget pour afficher une carte de contenu (audio, vidéo, article, etc.)
class ContentCard extends StatelessWidget {
  final ContentItem item;
  final VoidCallback onTap;
  final bool showDetails;
  final bool isHorizontal;

  const ContentCard({
    super.key,
    required this.item,
    required this.onTap,
    this.showDetails = true,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHorizontal) {
      return _buildHorizontalCard(context);
    } else {
      return _buildVerticalCard(context);
    }
  }

  /// Construit une carte horizontale
  Widget _buildHorizontalCard(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image ou icône
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: SizedBox(
                width: 60,
                height: 60,
                child: _buildContentIcon(),
              ),
            ),
            // Informations
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle != null && showDetails)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.subtitle!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (showDetails && (item.duration != null || item.viewCount != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (item.duration != null) ...[
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${item.duration} min',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (item.viewCount != null) ...[
                              const Icon(
                                Icons.visibility,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatViewCount(item.viewCount!),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Badge Live si nécessaire
            if (item.isLive)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildLiveBadge(),
              ),
          ],
        ),
      ),
    );
  }

  /// Construit une carte verticale
  Widget _buildVerticalCard(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image ou icône
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 100,
                    child: _buildContentIcon(),
                  ),
                ),
                // Badge Live si nécessaire
                if (item.isLive)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildLiveBadge(),
                  ),
              ],
            ),
            // Informations
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle != null && showDetails)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.subtitle!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (showDetails && (item.duration != null || item.viewCount != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (item.duration != null) ...[
                            const Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${item.duration} min',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (item.viewCount != null) ...[
                            const Icon(
                              Icons.visibility,
                              size: 12,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatViewCount(item.viewCount!),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit l'icône ou l'image du contenu
  Widget _buildContentIcon() {
    // Si une image est disponible, l'afficher
    if (item.imageUrl != null) {
      return Image.asset(
        item.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _getContentTypeIcon();
        },
      );
    }
    
    // Sinon, afficher une icône en fonction du type de contenu
    return _getContentTypeIcon();
  }

  /// Retourne l'icône en fonction du type de contenu
  Widget _getContentTypeIcon() {
    Color backgroundColor;
    IconData iconData;
    
    switch (item.type) {
      case ContentType.audio:
        backgroundColor = Colors.red.shade100;
        iconData = Icons.headphones;
        break;
      case ContentType.video:
        backgroundColor = Colors.blue.shade100;
        iconData = Icons.videocam;
        break;
      case ContentType.article:
        backgroundColor = Colors.purple.shade100;
        iconData = Icons.article;
        break;
      case ContentType.prayer:
        backgroundColor = Colors.grey.shade100;
        iconData = Icons.volunteer_activism;
        break;
      case ContentType.testimony:
        backgroundColor = Colors.pink.shade100;
        iconData = Icons.favorite;
        break;
      case ContentType.bibleStudy:
        backgroundColor = Colors.green.shade100;
        iconData = Icons.menu_book;
        break;
    }
    
    return Container(
      color: backgroundColor,
      child: Center(
        child: Icon(
          iconData,
          color: backgroundColor.withBlue(backgroundColor.blue - 40),
          size: 24,
        ),
      ),
    );
  }

  /// Construit le badge "LIVE"
  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.liveColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  /// Formate le nombre de vues
  String _formatViewCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    } else {
      return count.toString();
    }
  }
}
