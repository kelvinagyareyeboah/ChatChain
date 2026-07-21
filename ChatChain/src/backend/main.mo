00) + (rooms.size() * 300)
  };

  public shared ({ caller }) func deleteOldMessages(
    daysOld : Nat
  ) : async Result<Nat, Error> {
    
    if (not isAdmin(caller)) return #err(#Unauthorized);
    
    let deletedCount = performMessageCleanup(daysOld);
    #ok(deletedCount)
  };
  
  private func performMessageCleanup(daysOld : Nat) : Nat {
    let cutoff = now() - (daysOld * 24 * 60 * 60 * 1_000_000_000);
    let deleted = Buffer.Buffer<Nat>(100);
    
    for ((id, msg) in messages.entries()) {
      if (msg.timestamp < cutoff and not msg.pinned) {
        deleted.add(id);
      };
    };
    
    let count = deleted.size();
    for (id in deleted.vals()) messages.delete(id);
    count
  };
  
  public shared ({ caller }) func backupData() : async Result<{
    users : [User];
    messages : [Message];
    rooms : [ChatRoom];
    timestamp : Int;
  }, Error> {
    
    if (not isAdmin(caller)) return #err(#Unauthorized);
    
    #ok({
      users = Iter.toArray(users.vals());
      messages = Iter.toArray(messages.vals());
      rooms = Iter.toArray(rooms.vals());
      timestamp = now();
    })
  };
  
  // ===========================================================================
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


































































