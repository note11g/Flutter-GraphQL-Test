import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:graphql/client.dart';
import "package:http/http.dart" as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

main() => runApp(const MyApp());

class Config {
  static final HttpLink _link = HttpLink('https://pukuba.dev/api/');
  static final _client = GraphQLClient(link: _link, cache: GraphQLCache());

  static GraphQLClient getClient() => _client;
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.pink,
        ),
        home: const MainPage());
  }
}

class MainPage extends StatelessWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text("MainPage")),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
              style: ButtonStyle(
                  elevation: MaterialStateProperty.all(2.0),
                  backgroundColor:
                      MaterialStateProperty.all(Colors.pink.shade200)),
              child: const Text("graphQL File Upload Test",
                  style: TextStyle(color: Colors.white)),
              onPressed: () => Get.to(() => UploadTestPage())),
          TextButton(
              style: ButtonStyle(
                  elevation: MaterialStateProperty.all(2.0),
                  backgroundColor:
                      MaterialStateProperty.all(Colors.pink.shade200)),
              child: const Text("graphQL Query Test",
                  style: TextStyle(color: Colors.white)),
              onPressed: () => Get.to(() => QueryTestPage()))
        ]),
      ));
}

class UploadTestPage extends StatelessWidget {
  UploadTestPage({Key? key}) : super(key: key);

  final controller = Get.put(UploadController());

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text("Upload Test")),
      body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Obx(() => (controller.isInitImage.value
            ? Image.file(File(controller.selectedImage.value.path), height: 400)
            : const Text("non-selected image"))),
        TextButton(
            style: ButtonStyle(
                elevation: MaterialStateProperty.all(2.0),
                backgroundColor:
                    MaterialStateProperty.all(Colors.pink.shade200)),
            child:
                const Text("get file", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final ImagePicker _picker = ImagePicker();

              final XFile? photo = await _picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1920,
                  maxHeight: 1920,
                  imageQuality: 50);

              if (controller.isInitImage.value) {
                controller.selectedImage(photo);
              } else if (photo != null) {
                controller.selectedImage = photo.obs;
                controller.isInitImage(true);
              }
            }),
        TextButton(
            style: ButtonStyle(
                elevation: MaterialStateProperty.all(2.0),
                backgroundColor:
                    MaterialStateProperty.all(Colors.pink.shade200)),
            child: const Text("upload", style: TextStyle(color: Colors.white)),
            onPressed: controller.uploadImage),
        Center(
            child: Obx(() => (controller.isUploading.value
                ? const CircularProgressIndicator()
                : Container())))
      ])));
}

class UploadController extends GetxController {
  late final Rx<XFile> selectedImage;
  final isInitImage = false.obs;
  final isUploading = false.obs;

  Future uploadImage() async {
    if (!isInitImage.value) return;

    isUploading(true);
    const mutation = r"mutation($file: Upload!) { fileUploadTest(file:$file) }";

    final byteData = await selectedImage.value.readAsBytes();

    debugPrint("${await selectedImage.value.length() / 100000}MB");

    final image = http.MultipartFile.fromBytes('photo', byteData,
        contentType: MediaType("image", "png"),
        filename: "test_${DateTime.now()}.png");

    final opts =
        MutationOptions(document: gql(mutation), variables: {'file': image});

    final result = await Config.getClient().mutate(opts);

    if (result.hasException) {
      debugPrint(result.exception.toString());
    } else {
      Get.rawSnackbar(message: "성공!");
    }

    debugPrint("${result.data}");
    isUploading(false);
  }
}

class QueryTestPage extends StatelessWidget {
  QueryTestPage({Key? key}) : super(key: key);

  final controller = Get.put(QueryTestController());

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text("Query Test")),
      body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            color: Colors.grey.shade900,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: TextFormField(
                keyboardType: TextInputType.multiline,
                onChanged: controller.query,
                controller: controller.textEditController,
                decoration: const InputDecoration(border: InputBorder.none),
                maxLines: 6,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade100))),
        TextButton(
            style: ButtonStyle(
                elevation: MaterialStateProperty.all(2.0),
                backgroundColor:
                    MaterialStateProperty.all(Colors.pink.shade200)),
            child:
                const Text("send query", style: TextStyle(color: Colors.white)),
            onPressed: controller.uploadTest),
        Center(
            child: Obx(() => (controller.isUploading.value
                ? const CircularProgressIndicator()
                : Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    child: Text(controller.result.value))))),
      ])));
}

class QueryTestController extends GetxController {
  final isUploading = false.obs;
  final query = 'query {\n\ttest\n}'.obs;
  final textEditController = TextEditingController();
  final result = "여기에 결과가 표시됩니다.".obs;

  Future uploadTest() async {
    isUploading(true);
    final QueryOptions options = QueryOptions(document: gql(query.value));
    final QueryResult result = await Config.getClient().query(options);

    this.result(result.hasException
        ? result.exception.toString()
        : result.data.toString());
    isUploading(false);
  }

  @override
  void onInit() {
    textEditController.text = query.value;
    super.onInit();
  }
}
