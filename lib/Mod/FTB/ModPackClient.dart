import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:rpmlauncher/Launcher/Fabric/FabricClient.dart';
import 'package:rpmlauncher/Launcher/Forge/ForgeClient.dart';
import 'package:rpmlauncher/Launcher/InstanceRepository.dart';
import 'package:rpmlauncher/Launcher/MinecraftClient.dart';
import 'package:rpmlauncher/Model/IO/DownloadInfo.dart';
import 'package:rpmlauncher/Mod/ModLoader.dart';
import 'package:rpmlauncher/Model/Game/Instance.dart';

class FTBModPackClient extends MinecraftClient {
  @override
  MinecraftClientHandler handler;

  int totalFiles = 0;
  int parsedFiles = 0;
  int downloadedFiles = 0;

  FTBModPackClient._init({
    required Map versionInfo,
    required Map packData,
    required this.handler,
  });

  static Future<FTBModPackClient> createClient({
    required Map meta,
    required Map versionInfo,
    required Map packData,
    required String instanceDirName,
    required StateSetter setState,
  }) async {
    return await FTBModPackClient._init(
      versionInfo: versionInfo,
      packData: packData,
      handler: MinecraftClientHandler(
        versionID: meta['id'],
        meta: meta,
        instance: Instance(instanceDirName),
        setState: setState,
      ),
    )._ready(versionInfo, packData);
  }

  void getFiles(Map versionInfo) {
    totalFiles = ((versionInfo["files"] as List).cast<Map>())
        .where((element) => !element['serveronly'])
        .length;

    for (Map file in versionInfo["files"]) {
      bool serverOnly = file["serveronly"];
      if (serverOnly) continue; //如果非必要檔案則不下載 (目前RWL僅支援客戶端安裝)

      List<String> filePath = split(file['path']);
      filePath[0] = InstanceRepository.getInstanceDir(instance.name).path;
      String fileName = file["name"];
      infos.add(DownloadInfo(file["url"],
          savePath: join(joinAll(filePath), fileName),
          sh1Hash: file["sha1"],
          hashCheck: true, onDownloaded: () {
        setState(() {
          downloadedFiles++;
          nowEvent = "下載模組包資源中... ( $downloadedFiles/$totalFiles )";
        });
      }));

      parsedFiles++;

      setState(() {
        nowEvent = "取得模組包資源中... ( $parsedFiles/$totalFiles )";
      });
    }
  }

  Future<FTBModPackClient> _ready(
    Map versionInfo,
    packData,
  ) async {
    String versionID = versionInfo["targets"][1]["version"];
    String loaderID = versionInfo["targets"][0]["name"];
    String loaderVersionID = versionInfo["targets"][0]["version"];
    bool isFabric = loaderID.startsWith(ModLoaders.fabric.fixedString);
    bool isForge = loaderID.startsWith(ModLoaders.forge.fixedString);

    if (isFabric) {
      await FabricClient.createClient(
        setState: setState,
        meta: meta,
        versionID: versionID,
        loaderVersion: loaderVersionID,
        instance: instance,
      );
    } else if (isForge) {
      await ForgeClient.createClient(
          setState: setState,
          meta: meta,
          gameVersionID: versionID,
          forgeVersionID: loaderVersionID,
          instance: instance);
    }

    getFiles(versionInfo);
    await infos.downloadAll(onReceiveProgress: (_progress) {
      setState(() {});
    });
    finish = true;
    return this;
  }
}
