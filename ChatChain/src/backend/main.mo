
=========================================================
  // BATCH OPERATIONS
  // ===========================================================================
  
  public shared ({ caller }) func batchSendMessages(
    messagesToSend : [{
      content : Text;
      roomId : Nat;
    }]
  ) : async Result<[Message], Error> {
    
    if (isBanned(caller)) return #err(#Banned);
    
    validateMessages(messagesToSend, caller);
    
    let results = Buffer.Buffer<Message>(messagesToSend.size());
    for (msg in messagesToSend.vals()) {
      let result = createAndStoreMessage(msg, caller);
      results.add(result);
    };
    
    #ok(Buffer.toArray(results))
  };
  
  private func validateMessages(
    messages : [{ content : Text; roomId : Nat }],
    caller : Principal
  ) {
    for (msg in messages.vals()) {
      assert Text.size(msg.content) <= MAX_MESSAGE_LENGTH;
      assert hasRoomAccess(caller, msg.roomId);
    };
  };
  
  private func createAndStoreMessage(
    msg : { content : Text; roomId : Nat },
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


































































