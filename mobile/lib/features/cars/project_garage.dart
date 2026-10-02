import 'package:garona_mobile/core/config/app_config.dart';

class ProjectPhoto {
  const ProjectPhoto(this.id, this.url, this.caption);
  factory ProjectPhoto.fromJson(Map<String, Object?> data) => ProjectPhoto(
      data['id']! as String,
      AppConfig.resolveApiUrl(data['url'] as String)!,
      data['legenda'] as String? ?? '');
  final String id, url, caption;
}

const projectStageLabels = {
  'planejada': 'Planejado',
  'em_andamento': 'Em andamento',
  'concluida': 'Concluído',
};

class ProjectStage {
  const ProjectStage(
      {required this.id,
      required this.title,
      required this.status,
      this.description,
      this.evolutionId});
  factory ProjectStage.fromJson(Map<String, Object?> data) => ProjectStage(
      id: data['id']! as String,
      title: data['titulo']! as String,
      status: data['status']! as String,
      description: data['descricao'] as String?,
      evolutionId: data['evolucao_id'] as String?);
  final String id, title, status;
  final String? description, evolutionId;
}

class ProjectGarage {
  const ProjectGarage(this.photos, this.stages);
  factory ProjectGarage.fromJson(Map<String, Object?> data) => ProjectGarage(
      (data['fotos']! as List)
          .map(
              (e) => ProjectPhoto.fromJson(Map<String, Object?>.from(e as Map)))
          .toList(),
      (data['etapas']! as List)
          .map(
              (e) => ProjectStage.fromJson(Map<String, Object?>.from(e as Map)))
          .toList());
  final List<ProjectPhoto> photos;
  final List<ProjectStage> stages;
}
