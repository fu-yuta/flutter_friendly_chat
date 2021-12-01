class ChatResponse {
  final int id;
  final String userName;
  final String message;

  ChatResponse.fromJson(Map<String, dynamic> json) 
    : id = json['id'],
    userName = json['user_name'],
    message = json['message'];
}

class ChatRequest {
  final String userName;
  final String message;

  ChatRequest({
    this.userName = "Your Name",
    this.message = "",
  });

  Map<String, dynamic> toJson() => {
    'message': message,
    'user_name': userName,
  };
}

class UpdateChatRequest {
  final String message;

  UpdateChatRequest({
    this.message = "",
  });

  Map<String, dynamic> toJson() => {
    'message': message,
  };
}