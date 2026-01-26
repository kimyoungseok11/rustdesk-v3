import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/animated_rotation_widget.dart';
import 'package:flutter_hbb/common/widgets/custom_password.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/desktop/widgets/update_progress.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/plugin/ui_manager.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:flutter_hbb/utils/platform_channel.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;
import '../widgets/button.dart';

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({Key? key}) : super(key: key);

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

const borderColor = Color(0xFF2F65BA);

class _DesktopHomePageState extends State<DesktopHomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _leftPaneScrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;
  var systemError = '';
  StreamSubscription? _uniLinksSubscription;
  var svcStopped = false.obs;
  var watchIsCanScreenRecording = false;
  var watchIsProcessTrust = false;
  var watchIsInputMonitoring = false;
  var watchIsCanRecordAudio = false;
  Timer? _updateTimer;
  bool isCardClosed = false;

  final RxBool _editHover = false.obs;
  final RxBool _block = false.obs;

  final GlobalKey _childKey = GlobalKey();

  // 마트 이름 입력 및 전송을 위한 컨트롤러와 상태
  final TextEditingController _martNameController = TextEditingController();
  final RxBool _isSending = false.obs;
  final RxString _sendResult = ''.obs;
  final RxString _registeredMartName = ''.obs;  // 이미 등록된 마트 이름
  bool _martCheckDone = false;  // 마트 체크 완료 여부

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isIncomingOnly = bind.isIncomingOnly();
    return _buildBlock(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildLeftPane(context),
          if (!isIncomingOnly) const VerticalDivider(width: 1),
          if (!isIncomingOnly) Expanded(child: buildRightPane(context)),
        ],
      ),
    );
  }

  Widget _buildBlock({required Widget child}) {
    return buildRemoteBlock(
      block: _block,
      mask: true,
      use: canBeBlocked,
      child: child,
    );
  }

  Widget buildLeftPane(BuildContext context) {
    final isIncomingOnly = bind.isIncomingOnly();
    final isOutgoingOnly = bind.isOutgoingOnly();
    final children = <Widget>[
      if (!isOutgoingOnly) buildPresetPasswordWarning(),
      if (bind.isCustomClient())
        Align(alignment: Alignment.center, child: loadPowered(context)),
      Align(alignment: Alignment.center, child: loadLogo()),
      buildTip(context),
      if (!isOutgoingOnly) buildIDBoard(context),
      if (!isOutgoingOnly) buildPasswordBoard(context),
      FutureBuilder<Widget>(
        future: Future.value(
          Obx(() => buildHelpCards(stateGlobal.updateUrl.value)),
        ),
        builder: (_, data) {
          if (data.hasData) {
            if (isIncomingOnly) {
              if (isInHomePage()) {
                Future.delayed(Duration(milliseconds: 300), () {
                  _updateWindowSize();
                });
              }
            }
            return data.data!;
          } else {
            return const Offstage();
          }
        },
      ),
      buildPluginEntry(),
    ];
    if (isIncomingOnly) {
      children.addAll([
        Divider(),
        OnlineStatusWidget(
          onSvcStatusChanged: () {
            if (isInHomePage()) {
              Future.delayed(Duration(milliseconds: 300), () {
                _updateWindowSize();
              });
            }
          },
        ).marginOnly(bottom: 6, right: 6),
      ]);
    }
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Container(
        width: isIncomingOnly ? 280.0 : 200.0,
        color: Theme.of(context).colorScheme.background,
        child: Stack(
          children: [
            Column(
              children: [
                SingleChildScrollView(
                  controller: _leftPaneScrollController,
                  child: Column(key: _childKey, children: children),
                ),
                Expanded(child: Container()),
              ],
            ),
            if (isOutgoingOnly)
              Positioned(
                bottom: 6,
                left: 12,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    child: Obx(
                      () => Icon(
                        Icons.settings,
                        color: _editHover.value
                            ? textColor
                            : Colors.grey.withOpacity(0.5),
                        size: 22,
                      ),
                    ),
                    onTap: () => {
                      if (DesktopSettingPage.tabKeys.isNotEmpty)
                        {
                          DesktopSettingPage.switch2page(
                            DesktopSettingPage.tabKeys[0],
                          ),
                        },
                    },
                    onHover: (value) => _editHover.value = value,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  buildRightPane(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ConnectionPage(),
    );
  }

  buildIDBoard(BuildContext context) {
    final model = gFFI.serverModel;
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 11),
      height: 57,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 2,
            decoration: const BoxDecoration(color: MyTheme.accent),
          ).marginOnly(top: 5),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 25,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate("ID"),
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).textTheme.titleLarge?.color?.withOpacity(0.5),
                          ),
                        ).marginOnly(top: 5),
                        buildPopupMenu(context),
                      ],
                    ),
                  ),
                  Flexible(
                    child: GestureDetector(
                      onDoubleTap: () {
                        Clipboard.setData(
                          ClipboardData(text: model.serverId.text),
                        );
                        showToast(translate("Copied"));
                      },
                      child: TextFormField(
                        controller: model.serverId,
                        readOnly: true,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(top: 10, bottom: 10),
                        ),
                        style: TextStyle(fontSize: 22),
                      ).workaroundFreezeLinuxMint(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPopupMenu(BuildContext context) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    RxBool hover = false.obs;
    return InkWell(
      onTap: DesktopTabPage.onAddSetting,
      child: Tooltip(
        message: translate('Settings'),
        child: Obx(
          () => CircleAvatar(
            radius: 15,
            backgroundColor: hover.value
                ? Theme.of(context).scaffoldBackgroundColor
                : Theme.of(context).colorScheme.background,
            child: Icon(
              Icons.more_vert_outlined,
              size: 20,
              color: hover.value ? textColor : textColor?.withOpacity(0.5),
            ),
          ),
        ),
      ),
      onHover: (value) => hover.value = value,
    );
  }

  buildPasswordBoard(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(
        builder: (context, model, child) {
          return buildPasswordBoard2(context, model);
        },
      ),
    );
  }

  buildPasswordBoard2(BuildContext context, ServerModel model) {
    // 일회용 비밀번호 UI 제거
    // return const SizedBox.shrink();

    // 마트 이름 입력 및 RustDesk 등록 전송 UI
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, right: 16, top: 16.0),
      child: Obx(() {
        // 이미 등록된 마트인 경우
        if (_registeredMartName.value.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('등록된 마트', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey.shade100,
                ),
                child: Text(
                  _registeredMartName.value,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          );
        }

        // 미등록 마트인 경우 - 입력칸과 버튼 표시
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('마트 등록', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _martNameController,
              decoration: const InputDecoration(
                labelText: '마트 이름',
                hintText: '마트 이름을 입력하세요',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Obx(
                () => ElevatedButton(
                  onPressed: _isSending.value
                      ? null
                      : () => _sendRegistration(model),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isSending.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('등록하기'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => _sendResult.value.isNotEmpty
                  ? Text(
                      _sendResult.value,
                      style: TextStyle(
                        color: _sendResult.value.contains('성공')
                            ? Colors.green
                            : Colors.red,
                        fontSize: 12,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _sendRegistration(ServerModel model) async {
    final martName = _martNameController.text.trim();
    if (martName.isEmpty) {
      _sendResult.value = '마트 이름을 입력하세요';
      return;
    }

    _isSending.value = true;
    _sendResult.value = '';

    try {
      final id = model.serverId.text;
      final password = await bind.mainGetPermanentPassword();

      final url = Uri.parse('https://remote.qmk.me/api/register');
      final body = jsonEncode({
        'id': id,
        'password': password,
        'martName': martName,
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      // 응답 body 파싱
      final responseBody = jsonDecode(response.body);
      final success = responseBody['success'] ?? false;
      final message = responseBody['message'] ?? '';

      if (success) {
        _sendResult.value = '등록 성공!';
        _martNameController.clear();
        _showResultDialog(
          context,
          '등록 완료',
          message.isNotEmpty ? message : '마트가 성공적으로 등록되었습니다.',
          true,
        );
      } else {
        _sendResult.value = '등록 실패';
        _showResultDialog(
          context,
          '등록 실패',
          message.isNotEmpty ? message : message,
          false,
        );
      }
    } catch (e) {
      _sendResult.value = '오류 발생';
      _showResultDialog(context, '오류', '요청 중 오류가 발생했습니다: $e', false);
    } finally {
      _isSending.value = false;
    }
  }

  void _showResultDialog(
    BuildContext context,
    String title,
    String message,
    bool isSuccess,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 앱 시작 시 마트 등록 여부 확인
  Future<void> _checkMartRegistration() async {
    final id = gFFI.serverModel.serverId.text;
    _writeLog('=== 마트 체크 시작: ID=$id ===');

    try {
      final url = Uri.parse('https://remote.qmk.me/namecheck');
      final body = jsonEncode({'id': id});
      _writeLog('요청: $body');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      _writeLog('응답: ${response.body}');
      final responseBody = jsonDecode(response.body);
      final success = responseBody['success'] ?? true;
      final martName = responseBody['martName'];

      // success가 false이고 martName이 있으면 이미 등록된 상태
      if (!success && martName != null && martName.toString().isNotEmpty) {
        _registeredMartName.value = martName.toString();
        _writeLog('등록된 마트: ${_registeredMartName.value}');
      }
    } catch (e) {
      _writeLog('에러: $e');
    }
  }

  // 로그를 파일로 저장
  void _writeLog(String message) {
    try {
      final logFile = File('C:\\Temp\\martcheck_log.txt');
      // 폴더가 없으면 생성
      final dir = Directory('C:\\Temp');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final timestamp = DateTime.now().toString();
      logFile.writeAsStringSync('[$timestamp] $message\n', mode: FileMode.append);
    } catch (e) {
      // 로그 저장 실패 무시
    }
  }

  buildTip(BuildContext context) {
    final isOutgoingOnly = bind.isOutgoingOnly();
    return Padding(
      padding: const EdgeInsets.only(
        left: 20.0,
        right: 16,
        top: 16.0,
        bottom: 5,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              if (!isOutgoingOnly)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    translate("Your Desktop"),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
            ],
          ),
          SizedBox(height: 10.0),
          if (!isOutgoingOnly)
            Text(
              translate("desk_tip"),
              overflow: TextOverflow.clip,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (isOutgoingOnly)
            Text(
              translate("outgoing_only_desk_tip"),
              overflow: TextOverflow.clip,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget buildHelpCards(String updateUrl) {
    if (!bind.isCustomClient() &&
        updateUrl.isNotEmpty &&
        !isCardClosed &&
        bind.mainUriPrefixSync().contains('rustdesk')) {
      final isToUpdate = (isWindows || isMacOS) && bind.mainIsInstalled();
      String btnText = isToUpdate ? 'Update' : 'Download';
      GestureTapCallback onPressed = () async {
        final Uri url = Uri.parse('https://rustdesk.com/download');
        await launchUrl(url);
      };
      if (isToUpdate) {
        onPressed = () {
          handleUpdate(updateUrl);
        };
      }
      return buildInstallCard(
        "Status",
        "${translate("new-version-of-{${bind.mainGetAppNameSync()}}-tip")} (${bind.mainGetNewVersion()}).",
        btnText,
        onPressed,
        closeButton: true,
      );
    }
    if (systemError.isNotEmpty) {
      return buildInstallCard("", systemError, "", () {});
    }

    if (isWindows && !bind.isDisableInstallation()) {
      if (!bind.mainIsInstalled()) {
        return buildInstallCard(
          "",
          bind.isOutgoingOnly() ? "" : "install_tip",
          "Install",
          () async {
            await rustDeskWinManager.closeAllSubWindows();
            bind.mainGotoInstall();
          },
        );
      } else if (bind.mainIsInstalledLowerVersion()) {
        return buildInstallCard(
          "Status",
          "Your installation is lower version.",
          "Click to upgrade",
          () async {
            await rustDeskWinManager.closeAllSubWindows();
            bind.mainUpdateMe();
          },
        );
      }
    } else if (isMacOS) {
      final isOutgoingOnly = bind.isOutgoingOnly();
      if (!(isOutgoingOnly || bind.mainIsCanScreenRecording(prompt: false))) {
        return buildInstallCard(
          "Permissions",
          "config_screen",
          "Configure",
          () async {
            bind.mainIsCanScreenRecording(prompt: true);
            watchIsCanScreenRecording = true;
          },
          help: 'Help',
          link: translate("doc_mac_permission"),
        );
      } else if (!isOutgoingOnly && !bind.mainIsProcessTrusted(prompt: false)) {
        return buildInstallCard(
          "Permissions",
          "config_acc",
          "Configure",
          () async {
            bind.mainIsProcessTrusted(prompt: true);
            watchIsProcessTrust = true;
          },
          help: 'Help',
          link: translate("doc_mac_permission"),
        );
      } else if (!bind.mainIsCanInputMonitoring(prompt: false)) {
        return buildInstallCard(
          "Permissions",
          "config_input",
          "Configure",
          () async {
            bind.mainIsCanInputMonitoring(prompt: true);
            watchIsInputMonitoring = true;
          },
          help: 'Help',
          link: translate("doc_mac_permission"),
        );
      } else if (!isOutgoingOnly &&
          !svcStopped.value &&
          bind.mainIsInstalled() &&
          !bind.mainIsInstalledDaemon(prompt: false)) {
        return buildInstallCard("", "install_daemon_tip", "Install", () async {
          bind.mainIsInstalledDaemon(prompt: true);
        });
      }
      //// Disable microphone configuration for macOS. We will request the permission when needed.
      // else if ((await osxCanRecordAudio() !=
      //     PermissionAuthorizeType.authorized)) {
      //   return buildInstallCard("Permissions", "config_microphone", "Configure",
      //       () async {
      //     osxRequestAudio();
      //     watchIsCanRecordAudio = true;
      //   });
      // }
    } else if (isLinux) {
      if (bind.isOutgoingOnly()) {
        return Container();
      }
      final LinuxCards = <Widget>[];
      if (bind.isSelinuxEnforcing()) {
        // Check is SELinux enforcing, but show user a tip of is SELinux enabled for simple.
        final keyShowSelinuxHelpTip = "show-selinux-help-tip";
        if (bind.mainGetLocalOption(key: keyShowSelinuxHelpTip) != 'N') {
          LinuxCards.add(
            buildInstallCard(
              "Warning",
              "selinux_tip",
              "",
              () async {},
              marginTop: LinuxCards.isEmpty ? 20.0 : 5.0,
              help: 'Help',
              link:
                  'https://rustdesk.com/docs/en/client/linux/#permissions-issue',
              closeButton: true,
              closeOption: keyShowSelinuxHelpTip,
            ),
          );
        }
      }
      if (bind.mainCurrentIsWayland()) {
        LinuxCards.add(
          buildInstallCard(
            "Warning",
            "wayland_experiment_tip",
            "",
            () async {},
            marginTop: LinuxCards.isEmpty ? 20.0 : 5.0,
            help: 'Help',
            link: 'https://rustdesk.com/docs/en/client/linux/#x11-required',
          ),
        );
      } else if (bind.mainIsLoginWayland()) {
        LinuxCards.add(
          buildInstallCard(
            "Warning",
            "Login screen using Wayland is not supported",
            "",
            () async {},
            marginTop: LinuxCards.isEmpty ? 20.0 : 5.0,
            help: 'Help',
            link: 'https://rustdesk.com/docs/en/client/linux/#login-screen',
          ),
        );
      }
      if (LinuxCards.isNotEmpty) {
        return Column(children: LinuxCards);
      }
    }
    if (bind.isIncomingOnly()) {
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton(
          onPressed: () {
            SystemNavigator.pop(); // Close the application
            // https://github.com/flutter/flutter/issues/66631
            if (isWindows) {
              exit(0);
            }
          },
          child: Text(translate('Quit')),
        ),
      ).marginAll(14);
    }
    return Container();
  }

  Widget buildInstallCard(
    String title,
    String content,
    String btnText,
    GestureTapCallback onPressed, {
    double marginTop = 20.0,
    String? help,
    String? link,
    bool? closeButton,
    String? closeOption,
  }) {
    if (bind.mainGetBuildinOption(key: kOptionHideHelpCards) == 'Y' &&
        content != 'install_daemon_tip') {
      return const SizedBox();
    }
    void closeCard() async {
      if (closeOption != null) {
        await bind.mainSetLocalOption(key: closeOption, value: 'N');
        if (bind.mainGetLocalOption(key: closeOption) == 'N') {
          setState(() {
            isCardClosed = true;
          });
        }
      } else {
        setState(() {
          isCardClosed = true;
        });
      }
    }

    return Stack(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(
            0,
            marginTop,
            0,
            bind.isIncomingOnly() ? marginTop : 0,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color.fromARGB(255, 226, 66, 188),
                  Color.fromARGB(255, 244, 114, 124),
                ],
              ),
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  (title.isNotEmpty
                      ? <Widget>[
                          Center(
                            child: Text(
                              translate(title),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ).marginOnly(bottom: 6),
                          ),
                        ]
                      : <Widget>[]) +
                  <Widget>[
                    if (content.isNotEmpty)
                      Text(
                        translate(content),
                        style: TextStyle(
                          height: 1.5,
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                          fontSize: 13,
                        ),
                      ).marginOnly(bottom: 20),
                  ] +
                  (btnText.isNotEmpty
                      ? <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FixedWidthButton(
                                width: 150,
                                padding: 8,
                                isOutline: true,
                                text: translate(btnText),
                                textColor: Colors.white,
                                borderColor: Colors.white,
                                textSize: 20,
                                radius: 10,
                                onTap: onPressed,
                              ),
                            ],
                          ),
                        ]
                      : <Widget>[]) +
                  (help != null
                      ? <Widget>[
                          Center(
                            child: InkWell(
                              onTap: () async =>
                                  await launchUrl(Uri.parse(link!)),
                              child: Text(
                                translate(help),
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ).marginOnly(top: 6),
                          ),
                        ]
                      : <Widget>[]),
            ),
          ),
        ),
        if (closeButton != null && closeButton == true)
          Positioned(
            top: 18,
            right: 0,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: closeCard,
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _updateTimer = periodic_immediate(const Duration(seconds: 1), () async {
      await gFFI.serverModel.fetchID();

      // ID가 로드되면 마트 등록 여부 확인 (한 번만 실행)
      if (!_martCheckDone && gFFI.serverModel.serverId.text.isNotEmpty) {
        _martCheckDone = true;
        _checkMartRegistration();
      }

      final error = await bind.mainGetError();
      if (systemError != error) {
        systemError = error;
        setState(() {});
      }
      final v = await mainGetBoolOption(kOptionStopService);
      if (v != svcStopped.value) {
        svcStopped.value = v;
        setState(() {});
      }
      if (watchIsCanScreenRecording) {
        if (bind.mainIsCanScreenRecording(prompt: false)) {
          watchIsCanScreenRecording = false;
          setState(() {});
        }
      }
      if (watchIsProcessTrust) {
        if (bind.mainIsProcessTrusted(prompt: false)) {
          watchIsProcessTrust = false;
          setState(() {});
        }
      }
      if (watchIsInputMonitoring) {
        if (bind.mainIsCanInputMonitoring(prompt: false)) {
          watchIsInputMonitoring = false;
          // Do not notify for now.
          // Monitoring may not take effect until the process is restarted.
          // rustDeskWinManager.call(
          //     WindowType.RemoteDesktop, kWindowDisableGrabKeyboard, '');
          setState(() {});
        }
      }
      if (watchIsCanRecordAudio) {
        if (isMacOS) {
          Future.microtask(() async {
            if ((await osxCanRecordAudio() ==
                PermissionAuthorizeType.authorized)) {
              watchIsCanRecordAudio = false;
              setState(() {});
            }
          });
        } else {
          watchIsCanRecordAudio = false;
          setState(() {});
        }
      }
    });
    Get.put<RxBool>(svcStopped, tag: 'stop-service');
    rustDeskWinManager.registerActiveWindowListener(onActiveWindowChanged);

    screenToMap(window_size.Screen screen) => {
      'frame': {
        'l': screen.frame.left,
        't': screen.frame.top,
        'r': screen.frame.right,
        'b': screen.frame.bottom,
      },
      'visibleFrame': {
        'l': screen.visibleFrame.left,
        't': screen.visibleFrame.top,
        'r': screen.visibleFrame.right,
        'b': screen.visibleFrame.bottom,
      },
      'scaleFactor': screen.scaleFactor,
    };

    bool isChattyMethod(String methodName) {
      switch (methodName) {
        case kWindowBumpMouse:
          return true;
      }

      return false;
    }

    rustDeskWinManager.setMethodHandler((call, fromWindowId) async {
      if (!isChattyMethod(call.method)) {
        debugPrint(
          "[Main] call ${call.method} with args ${call.arguments} from window $fromWindowId",
        );
      }
      if (call.method == kWindowMainWindowOnTop) {
        windowOnTop(null);
      } else if (call.method == kWindowGetWindowInfo) {
        final screen = (await window_size.getWindowInfo()).screen;
        if (screen == null) {
          return '';
        } else {
          return jsonEncode(screenToMap(screen));
        }
      } else if (call.method == kWindowGetScreenList) {
        return jsonEncode(
          (await window_size.getScreenList()).map(screenToMap).toList(),
        );
      } else if (call.method == kWindowActionRebuild) {
        reloadCurrentWindow();
      } else if (call.method == kWindowEventShow) {
        await rustDeskWinManager.registerActiveWindow(call.arguments["id"]);
      } else if (call.method == kWindowEventHide) {
        await rustDeskWinManager.unregisterActiveWindow(call.arguments['id']);
      } else if (call.method == kWindowConnect) {
        await connectMainDesktop(
          call.arguments['id'],
          isFileTransfer: call.arguments['isFileTransfer'],
          isViewCamera: call.arguments['isViewCamera'],
          isTerminal: call.arguments['isTerminal'],
          isTcpTunneling: call.arguments['isTcpTunneling'],
          isRDP: call.arguments['isRDP'],
          password: call.arguments['password'],
          forceRelay: call.arguments['forceRelay'],
          connToken: call.arguments['connToken'],
        );
      } else if (call.method == kWindowBumpMouse) {
        return RdPlatformChannel.instance.bumpMouse(
          dx: call.arguments['dx'],
          dy: call.arguments['dy'],
        );
      } else if (call.method == kWindowEventMoveTabToNewWindow) {
        final args = call.arguments.split(',');
        int? windowId;
        try {
          windowId = int.parse(args[0]);
        } catch (e) {
          debugPrint("Failed to parse window id '${call.arguments}': $e");
        }
        WindowType? windowType;
        try {
          windowType = WindowType.values.byName(args[3]);
        } catch (e) {
          debugPrint("Failed to parse window type '${call.arguments}': $e");
        }
        if (windowId != null && windowType != null) {
          await rustDeskWinManager.moveTabToNewWindow(
            windowId,
            args[1],
            args[2],
            windowType,
          );
        }
      } else if (call.method == kWindowEventOpenMonitorSession) {
        final args = jsonDecode(call.arguments);
        final windowId = args['window_id'] as int;
        final peerId = args['peer_id'] as String;
        final display = args['display'] as int;
        final displayCount = args['display_count'] as int;
        final windowType = args['window_type'] as int;
        final screenRect = parseParamScreenRect(args);
        await rustDeskWinManager.openMonitorSession(
          windowId,
          peerId,
          display,
          displayCount,
          screenRect,
          windowType,
        );
      } else if (call.method == kWindowEventRemoteWindowCoords) {
        final windowId = int.tryParse(call.arguments);
        if (windowId != null) {
          return jsonEncode(
            await rustDeskWinManager.getOtherRemoteWindowCoords(windowId),
          );
        }
      }
    });
    _uniLinksSubscription = listenUniLinks();

    if (bind.isIncomingOnly()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateWindowSize();
      });
    }
    WidgetsBinding.instance.addObserver(this);
  }

  _updateWindowSize() {
    RenderObject? renderObject = _childKey.currentContext?.findRenderObject();
    if (renderObject == null) {
      return;
    }
    if (renderObject is RenderBox) {
      final size = renderObject.size;
      if (size != imcomingOnlyHomeSize) {
        imcomingOnlyHomeSize = size;
        windowManager.setSize(getIncomingOnlyHomeSize());
      }
    }
  }

  @override
  void dispose() {
    _uniLinksSubscription?.cancel();
    Get.delete<RxBool>(tag: 'stop-service');
    _updateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      shouldBeBlocked(_block, canBeBlocked);
    }
  }

  Widget buildPluginEntry() {
    final entries = PluginUiManager.instance.entries.entries;
    return Offstage(
      offstage: entries.isEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...entries.map((entry) {
            return entry.value;
          }),
        ],
      ),
    );
  }
}

void setPasswordDialog({VoidCallback? notEmptyCallback}) async {
  final pw = await bind.mainGetPermanentPassword();
  final p0 = TextEditingController(text: pw);
  final p1 = TextEditingController(text: pw);
  var errMsg0 = "";
  var errMsg1 = "";
  final RxString rxPass = pw.trim().obs;
  final rules = [
    DigitValidationRule(),
    UppercaseValidationRule(),
    LowercaseValidationRule(),
    // SpecialCharacterValidationRule(),
    MinCharactersValidationRule(8),
  ];
  final maxLength = bind.mainMaxEncryptLen();

  gFFI.dialogManager.show((setState, close, context) {
    submit() {
      setState(() {
        errMsg0 = "";
        errMsg1 = "";
      });
      final pass = p0.text.trim();
      if (pass.isNotEmpty) {
        final Iterable violations = rules.where((r) => !r.validate(pass));
        if (violations.isNotEmpty) {
          setState(() {
            errMsg0 =
                '${translate('Prompt')}: ${violations.map((r) => r.name).join(', ')}';
          });
          return;
        }
      }
      if (p1.text.trim() != pass) {
        setState(() {
          errMsg1 =
              '${translate('Prompt')}: ${translate("The confirmation is not identical.")}';
        });
        return;
      }
      bind.mainSetPermanentPassword(password: pass);
      if (pass.isNotEmpty) {
        notEmptyCallback?.call();
      }
      close();
    }

    return CustomAlertDialog(
      title: Text(translate("Set Password")),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8.0),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: translate('Password'),
                      errorText: errMsg0.isNotEmpty ? errMsg0 : null,
                    ),
                    controller: p0,
                    autofocus: true,
                    onChanged: (value) {
                      rxPass.value = value.trim();
                      setState(() {
                        errMsg0 = '';
                      });
                    },
                    maxLength: maxLength,
                  ).workaroundFreezeLinuxMint(),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: PasswordStrengthIndicator(password: rxPass)),
              ],
            ).marginSymmetric(vertical: 8),
            const SizedBox(height: 8.0),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: translate('Confirmation'),
                      errorText: errMsg1.isNotEmpty ? errMsg1 : null,
                    ),
                    controller: p1,
                    onChanged: (value) {
                      setState(() {
                        errMsg1 = '';
                      });
                    },
                    maxLength: maxLength,
                  ).workaroundFreezeLinuxMint(),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Obx(
              () => Wrap(
                runSpacing: 8,
                spacing: 4,
                children: rules.map((e) {
                  var checked = e.validate(rxPass.value.trim());
                  return Chip(
                    label: Text(
                      e.name,
                      style: TextStyle(
                        color: checked
                            ? const Color(0xFF0A9471)
                            : Color.fromARGB(255, 198, 86, 157),
                      ),
                    ),
                    backgroundColor: checked
                        ? const Color(0xFFD0F7ED)
                        : Color.fromARGB(255, 247, 205, 232),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        dialogButton("Cancel", onPressed: close, isOutline: true),
        dialogButton("OK", onPressed: submit),
      ],
      onSubmit: submit,
      onCancel: close,
    );
  });
}
