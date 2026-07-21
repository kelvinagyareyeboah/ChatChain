xt; roomId : Nat },
    caller : Principal
  ) : MmessageId, msg.content, caller, msg.roomId, null, #Text, null, null);
    
    storeMessage(message);
    updateStatistics(caller, msg.roomId);
    
    message
  };
}


































































