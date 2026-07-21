>,sender, userMessageCounts);
    if (msg.timestamp >= weekAgo) activeUsers.put(msg.sender, true);
  };
  
  private func updateUserMessageCount(
    userId : Principal,
    counts : TrieMap.TrieMap<Principal, Nat>
  ) {
    switch (counts.get(userId)) {
      case (?count) counts.put(userId, count + 1);
      case null counts.put(userId, 1);
    };
  };
  
  private func getTopPosters(
    userMessageCounts : TrieMap.TrieMap<Principal, Nat>,
    limit : Nat
  ) : [(Principal, Nat)] {
    let entries = Iter.toArray(userMessageCounts.entries());
    let sorted = Array.sort(entries, func(a : (Principal, Nat), b : (Principal, Nat)) : Order.Order {
      if (a.1 > b.1) #greater else if (a.1 < b.1) #less else #equal
    });
    
    if (sorted.size() > limit) Array.subArray(sorted, 0, limit) else sorted
  };
  
  public query func version() : async Text {
    "ChatChain v5.2.0"
  };
  
  public query func getSystemHealth() : async {
    canisterId : Principal;
    version : Text;
    uptime : Int;
    userCount : Nat;
    messageCount : Nat;
    roomCount : Nat;
    storageSize : Nat;
    isHealthy : Bool;
  } {
    let storageSize = estimateStorageSize();
    
    {
      canisterId = Principal.fromActor(ChatChain);
      version = "5.2.0";
      uptime = now() - canisterCreatedAt;
      userCount = users.size();
      messageCount = messages.size();
      roomCount = rooms.size();
      storageSize = storageSize;
      isHealthy = true;
    }
  };
  
  private func estimateStorageSize() : Nat {
    (users.size() * 500) + (messages.size() * 200) + (rooms.size() * 300)
  };
  
  // ===========================================================================
  // ADMIN FUNCTIONS
  // ===========================================================================
  
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


































































