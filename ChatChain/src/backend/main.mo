
  ) : async Result<Message, Error> {
    
    if (isBanned(caller)) return #err(#Banned);
    if (Text.size(content) > MAX_MESSAGE_LENGTH) return #err(#MessageTooLong);
    if (messageRateLimiter.checkRateLimit(caller)) return #err(#RateLimited);
    if (not hasRoomAccess(caller, roomId)) return #err(#NoPermission);
    
    let messageId = nextMessageId;
    nextMessageId += 1;
    
    let message = createMessage(messageId, content, caller, roomId, replyTo, messageType, poll, metadata);
    
    storeMessage(message);
    updateStatistics(caller, roomId);
    
    if (messageId % 100 == 0) periodicCleanup();
    
    #ok(message)
  };
  
  private func hasRoomAccess(userId : Principal, roomId : Nat) : Bool {
    switch (userRoomMembership.get(userId)) {
      case (?buffer) Buffer.contains(buffer, roomId, Nat.equal);
      case null false;
    }
  };
  
  private func createMessage(
    id : Nat,
    content : Text,
    sender : Principal,
    roomId : Nat,
    replyTo : ?Nat,
    messageType : MessageType,
    poll : ?Poll,
    metadata : ?Blob
  ) : Message {
    {
      id = id;
      sender = sender;
      content = content;
      timestamp = now();
      edited = false;
      deleted = false;
      pinned = false;
      reactions = [];
      replyTo = replyTo;
      threadId = null;
      roomId = roomId;
      mentions = extractMentions(content);
      attachments = [];
      messageType = messageType;
      poll = poll;
      metadata = metadata;
      encryptionKey = null;
    }
  };
  
  private func storeMessage(message : Message) {
    messages.put(message.id, message);
    
    let roomBuffer = getOrCreateBuffer(messagesByRoom, message.roomId, 100);
    roomBuffer.add(message.id);
  };
  
  private func updateStatistics(userId : Principal, roomId : Nat) {
    incrementMessageCount(userId);
    updateRoomActivity(roomId);
  };
  
  public shared ({ caller }) func editMessage(
    messageId : Nat,
    newContent : Text
  ) : async Result<Message, Error> {
    
    switch (messages.get(messageId)) {
      case null #err(#NotFound);
      case (?message) {
        if (not canEditMessage(message, caller)) return #err(#Unauthorized);
        
        let updatedMessage = createUpdatedMessage(message, newContent);
        messages.put(messageId, updatedMessage);
        
        #ok(updatedMessage)
      };
    }
  };
  
  private func canEditMessage(message : Message, caller : Principal) : Bool {
    Principal.equal(message.sender, caller)
    and now() - message.timestamp <= EDIT_WINDOW_SECONDS * 1_000_000_000
  };
  
  private func createUpdatedMessage(message : Message, newContent : Text) : Message {
    {
      message with
      content = newContent;
      edited = true;
      mentions = extractMentions(newContent);
    }
  };
  
  public shared ({ caller }) func deleteMessage(messageId : Nat) : async Result<Bool, Error> {
    switch (messages.get(messageId)) {
      case null #err(#NotFound);
      case (?message) {
        if (not canDeleteMessage(message, caller)) return #err(#Unauthorized);
        
        messages.put(messageId, { message with deleted = true });
        #ok(true)
      };
    }
  };
  
  private func canDeleteMessage(message : Message, caller : Principal) : Bool {
    Principal.equal(message.sender, caller) or isModOrAdmin(caller)
  };
  
  public query func getMessages(
    roomId : Nat,
    limit : Nat,
    before : ?Nat
  ) : async [Message] {
    
    let actualLimit = Nat.min(limit, DEFAULT_PAGE_SIZE);
    switch (messagesByRoom.get(roomId)) {
      case null [];
      case (?messageIds) {
        let messages = collectMessages(messageIds, actualLimit, before);
        Buffer.toArray(messages)
      };
    }
  };
  
  private func collectMessages(
    messageIds : Buffer.Buffer<Nat>,
    limit : Nat,
    before : ?Nat
  ) : Buffer.Buffer<Message> {
    let results = Buffer.Buffer<Message>(limit);
    let size = messageIds.size();
    if (size == 0) return results;
    
    let startIdx = findStartIndex(messageIds, size, before);
    var idx = startIdx;
    var count = 0;
    
    while (idx >= 0 and count < limit) {
      addMessageIfValid(messageIds.get(idx), results);
      idx -= 1;
      count += 1;
    };
    
    results
  };
  
  private func findStartIndex(
    messageIds : Buffer.Buffer<Nat>,
    size : Nat,
    before : ?Nat
  ) : Nat {
    switch (before) {
      case (?msgId) {
        for (i in Iter.range(0, size - 1)) {
          if (messageIds.get(i) == msgId) return if (i > 0) i - 1 else 0;
        };
        0
      };
      case null size - 1;
    }
  };
  
  private func addMessageIfValid(messageId : Nat, buffer : Buffer.Buffer<Message>) {
    switch (messages.get(messageId)) {
      case (?msg) if (not msg.deleted) buffer.add(msg);
      case null {};
    };
  };
  
  // ===========================================================================
  // QUERIES
  // ===========================================================================
  
  public query ({ caller }) func whoAmI() : async ?User {
    users.get(caller)
  };
  
  public query func getOnlineUsers(roomId : ?Nat) : async [User] {
    let now = Time.now();
    
    if (shouldUseCache(roomId, now)) {
      switch (roomId) {
        case (?id) {
          switch (onlineUsersCache.get(id)) {
            case (?cached) return cached;
            case null {};
          };
        };
        case null {};
      };
    };
    
    let result = calculateOnlineUsers(roomId, now);
    
    updateCache(roomId, result, now);
    result
  };
  
  private func shouldUseCache(roomId : ?Nat, now : Int) : Bool {
    now - lastCacheUpdate < CACHE_TTL
  };
  
  private func calculateOnlineUsers(roomId : ?Nat, now : Int) : [User] {
    let results = Buffer.Buffer<User>(50);
    
    for (user in users.vals()) {
      if (user.banned) continue;
      if (not isUserOnline(user, now)) continue;
      if (not isUserInRoom(user, roomId)) continue;
      
      results.add(user);
    };
    
    Buffer.toArray(results)
  };
  
  private func isUserOnline(user : User, now : Int) : Bool {
    (now - user.lastSeen) < ONLINE_THRESHOLD
  };
  
  private func isUserInRoom(user : User, roomId : ?Nat) : Bool {
    switch (roomId) {
      case (?rId) {
        switch (userRoomMembership.get(user.id)) {
          case (?buffer) Buffer.contains(buffer, rId, Nat.equal);
          case null false;
        };
      };
      case null true;
    }
  };
  
  private func updateCache(roomId : ?Nat, users : [User], now : Int) {
    lastCacheUpdate := now;
    switch (roomId) {
      case (?id) onlineUsersCache.put(id, users);
      case null {};
    };
  };
  
  public query func getRoomStatistics(roomId : Nat) : async ?{
    room : ChatRoom;
    totalMessages : Nat;
    activeUsers : Nat;
    messagesToday : Nat;
    topPosters : [(Principal, Nat)];
  } {
    switch (rooms.get(roomId)) {
      case null null;
      case (?room) ?analyzeRoom(room);
    }
  };
  
  private func analyzeRoom(room : ChatRoom) : {
    room : ChatRoom;
    totalMessages : Nat;
    activeUsers : Nat;
    messagesToday : Nat;
    topPosters : [(Principal, Nat)];
  } {
    let dayAgo = now() - (24 * 60 * 60 * 1_000_000_000);
    let weekAgo = now() - (7 * 24 * 60 * 60 * 1_000_000_000);
    
    let stats = collectRoomStatistics(room.id, dayAgo, weekAgo);
    let topPosters = getTopPosters(stats.userMessageCounts, 5);
    
    {
      room = room;
      totalMessages = stats.totalMessages;
      activeUsers = stats.activeUsers.size();
      messagesToday = stats.messagesToday;
      topPosters = topPosters;
    }
  };
  
  private type RoomStatistics = {
    totalMessages : Nat;
    messagesToday : Nat;
    activeUsers : TrieMap.TrieMap<Principal, Bool>;
    userMessageCounts : TrieMap.TrieMap<Principal, Nat>;
  };
  
  private func collectRoomStatistics(
    roomId : Nat,
    dayAgo : Int,
    weekAgo : Int
  ) : RoomStatistics {
    let userMessageCounts = TrieMap.TrieMap<Principal, Nat>(Principal.equal, Principal.hash);
    let activeUsers = TrieMap.TrieMap<Principal, Bool>(Principal.equal, Principal.hash);
    var totalMessages : Nat = 0;
    var messagesToday : Nat = 0;
    
    switch (messagesByRoom.get(roomId)) {
      case (?messageIds) {
        for (msgId in messageIds.vals()) {
          switch (messages.get(msgId)) {
            case (?msg) if (not msg.deleted) {
              totalMessages += 1;
              updateMessageStats(msg, dayAgo, weekAgo, userMessageCounts, activeUsers);
              if (msg.timestamp >= dayAgo) messagesToday += 1;
            };
            case null {};
          };
        };
      };
      case null {};
    };
    
    { totalMessages; messagesToday; activeUsers; userMessageCounts }
  };
  
  private func updateMessageStats(
    msg : Message,
    dayAgo : Int,
    weekAgo : Int,
    userMessageCounts : TrieMap.TrieMap<Principal, Nat>,
    activeUsers : TrieMap.TrieMap<Principal, Bool>
  ) {
    updateUserMessageCount(msg.sender, userMessageCounts);
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


































































