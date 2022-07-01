import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
// import 'package:tasks_app/Todo.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web_socket_channel/io.dart';

import 'todo.dart';

class tasksServices extends ChangeNotifier {
  List<Todo> tasks = [];
  final String _rpcUrl =
      Platform.isAndroid ? 'http://10.0.2.2:7545' : 'http://127.0.0.1:7545';
  final String _wsUrl =
      Platform.isAndroid ? 'http://10.0.2.2:7545' : 'ws://127.0.0.1:7545';
  bool isLoading = true;

  final String _privatekey =
      '721182f13ab166e916cdd637f3f907a933d5dfc98519d812be35e9d657f98507';
  late Web3Client _web3cient;

  tasksServices() {
    init();
  }

  Future<void> init() async {
    _web3cient = Web3Client(
      _rpcUrl,
      http.Client(),
      socketConnector: () {
        return IOWebSocketChannel.connect(_wsUrl).cast<String>();
      },
    );
    await getABI();
    await getCredentials();
    await getDeployedContract();
  }

  late ContractAbi _abiCode;
  late EthereumAddress _contractAddress;
  Future<void> getABI() async {
    String abiFile =
        await rootBundle.loadString('build/contracts/TodoList.json');
    var jsonABI = jsonDecode(abiFile);
    _abiCode =
        ContractAbi.fromJson(jsonEncode(jsonABI['abi']), 'tasksContract');
    _contractAddress =
        EthereumAddress.fromHex(jsonABI["networks"]["5777"]["address"]);
  }

  late EthPrivateKey _creds;
  Future<void> getCredentials() async {
    _creds = EthPrivateKey.fromHex(_privatekey);
  }

  late DeployedContract _deployedContract;
  late ContractFunction _createTodo;
  late ContractFunction _deleteTodo;
  late ContractFunction _tasks;
  late ContractFunction _createTask;

  Future<void> getDeployedContract() async {
    _deployedContract = DeployedContract(_abiCode, _contractAddress);
    _createTask = _deployedContract.function('createTask');
    // _deleteTodo = _deployedContract.function('deleteTodo');
    _tasks = _deployedContract.function('tasks');
    // _TodoCount = _deployedContract.function('TodoCount');
    await fetchtasks();
  }

  Future<void> fetchtasks() async {
    List totalTaskList = await _web3cient.call(
      contract: _deployedContract,
      function: _tasks,
      params: [],
    );

    int totalTaskLen = totalTaskList[0].toInt();
    tasks.clear();
    for (var i = 0; i < totalTaskLen; i++) {
      var temp = await _web3cient.call(
          contract: _deployedContract,
          function: _tasks,
          params: [BigInt.from(i)]);
      if (temp[1] != "") {
        tasks.add(
          Todo(
            id: (temp[0] as BigInt).toInt(),
            content: temp[1],
            completed: temp[2],
          ),
        );
      }
    }
    isLoading = false;

    notifyListeners();
  }

  Future<void> addTodo(String title, String description) async {
    await _web3cient.sendTransaction(
      _creds,
      Transaction.callContract(
        contract: _deployedContract,
        function: _createTodo,
        parameters: [title, description],
      ),
    );
    isLoading = true;
    fetchtasks();
  }

  Future<void> deleteTodo(int id) async {
    await _web3cient.sendTransaction(
      _creds,
      Transaction.callContract(
        contract: _deployedContract,
        function: _deleteTodo,
        parameters: [BigInt.from(id)],
      ),
    );
    isLoading = true;
    notifyListeners();
    fetchtasks();
  }
}
