xt; roomId : Nat },
    caller : Principal
  ) : Message {
    let messageId = nextMessageId;
    nextMessageId += 1;
    
    let message = createMessage(messageId, msg.content, caller, msg.roomId, null, #Text, null, null);
    
    storeMessage(message);
    updateStatistics(caller, msg.roomId);
    
    message
  };
}


































































