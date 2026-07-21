// ===========================================================================
// ChatChain — Internet Computer chat canister
//
// NOTE: The source pasted to me was truncated at the top (it began mid-way
// through the `Poll` type definition), so the imports/actor header and the
// type declarations above `Poll` below were reconstructed to match how the
// rest of the file uses them. Everything from `Poll` onward is your
// original code with the fixes described in my reply applied.
// ===========================================================================

import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import TrieMap "mo:base/TrieMap";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Order "mo:base/Order";
import Hash "mo:base/Hash";
import Prim "mo:prim";

actor ChatChain {

  // ===========================================================================
  // ENUM-LIKE TYPES
  // ===========================================================================

  public type UserRole = { #Owner; #Admin; #Moderator; #User };
  public type UserStatus = { #Online; #Away; #Busy; #Offline };
  public type ChatRoomType = { #Public; #Private; #DirectMessage };
  public type MessageType = { #Text; #Image; #File; #System; #Poll };
  public type NotificationType = {
    #Mention;
    #Reply;
    #Reaction;
    #RoomInvite;
    #SystemAlert;
  };

  public type UserPreferences = {
    theme : Text;
    notifications : Bool;
    language : Text;
    autoDeleteDMs : Bool;
    showReadReceipts : Bool;
  };

  public type User = {
    id : Principal;
    displayName : Text;
    username : Text;
    bio : ?Text;
    avatar : ?Text;
    role : UserRole;
    banned : Bool;
    bannedUntil : ?Int;
    lastSeen : Int;
    status : UserStatus;
    joined : Int;
    messageCount : Nat;
    reputation : Int;
    preferences : UserPreferences;
    isVerified : Bool;
  };

  public type Reaction = {
    emoji : Text;
    users : [Principal];
  };

  public type Attachment = {
    id : Nat;
    url : Text;
    fileName : Text;
    fileSize : Nat;
    mimeType : Text;
  };

  public type Poll = {
    question : Text;
    options : [Text];
    votes : [Nat];
    endsAt : ?Int;
    voters : [Principal];
  };

  public type Message = {
    id : Nat;
    sender : Principal;
    content : Text;
    timestamp : Int;
    edited : Bool;
    deleted : Bool;
    pinned : Bool;
    reactions : [Reaction];
    replyTo : ?Nat;
    threadId : ?Nat;
    roomId : Nat;
    mentions : [Principal];
    attachments : [Attachment];
    messageType : MessageType;
    poll : ?Poll;
    metadata : ?Blob;
    encryptionKey : ?Text;
  };

  public type ChatRoom = {
    id : Nat;
    name : Text;
    description : ?Text;
    roomType : ChatRoomType;
    moderators : [Principal];
    createdBy : Principal;
    createdAt : Int;
    messageCount : Nat;
    isArchived : Bool;
    lastActivity : Int;
    icon : ?Text;
    rules : ?Text;
    maxMembers : ?Nat;
  };

  public type Notification = {
    id : Nat;
    userId : Principal;
    type_ : NotificationType;
    messageId : ?Nat;
    roomId : ?Nat;
    fromUser : ?Principal;
    content : Text;
    timestamp : Int;
    read : Bool;
  };

  public type TypingIndicator = {
    userId : Principal;
    roomId : Nat;
    timestamp : Int;
  };

  public type Error = {
    #Unauthorized;
    #NotFound;
    #InvalidInput;
    #RateLimited;
    #Banned;
    #NoPermission;
    #AlreadyExists;
    #RoomFull;
    #StorageLimitExceeded;
    #UserBlocked;
    #MessageTooLong;
    #InvalidAttachment;
    #PollEnded;
    #DuplicateVote;
    #EncryptionError;
    #InsufficientCycles;
  };

  public type Result<T, E> = Result.Result<T, E>;

  // ===========================================================================
  // CONSTANTS
  // ===========================================================================

  let EDIT_WINDOW_SECONDS : Int = 900; // 15 minutes
  let MAX_MESSAGE_LENGTH : Nat = 5000;
  let MAX_DISPLAY_NAME_LENGTH : Nat = 50;
  let MAX_ROOM_NAME_LENGTH : Nat = 100;
  let MAX_ROOM_DESCRIPTION_LENGTH : Nat = 1000;
  let RATE_LIMIT_SECONDS : Nat = 1;
  let MAX_MESSAGES_PER_USER_PER_DAY : Nat = 5000;
  let MESSAGE_RETENTION_DAYS : Int = 365;
  let MAX_PINNED_MESSAGES : Nat = 10;
  let MAX_UPLOAD_SIZE_BYTES : Nat = 10_000_000;
  let TYPING_INDICATOR_TIMEOUT : Int = 10_000_000_000;
  let NOTIFICATION_RETENTION_DAYS : Int = 30;
  let DEFAULT_PAGE_SIZE : Nat = 50;
  let MAX_SEARCH_RESULTS : Nat = 100;
  let CACHE_TTL : Int = 30_000_000_000;
  let ONLINE_THRESHOLD : Int = 300_000_000_000; // 5 minutes

  // ===========================================================================
  // STABLE STATE
  // ===========================================================================

  stable var nextMessageId : Nat = 0;
  stable var nextRoomId : Nat = 0;
  stable var nextNotificationId : Nat = 0;
  stable var nextAttachmentId : Nat = 0;
  stable var canisterCreatedAt : Int = Time.now();

  stable var stableUsers : [(Principal, User)] = [];
  stable var stableMessages : [(Nat, Message)] = [];
  stable var stableRooms : [(Nat, ChatRoom)] = [];
  stable var stableUserRoomMembership : [(Principal, [Nat])] = [];
  stable var stableRoomMembers : [(Nat, [Principal])] = [];
  stable var stableMessagesByRoom : [(Nat, [Nat])] = [];

  // ===========================================================================
  // STATE MANAGEMENT
  // ===========================================================================

  private let users = HashMap.HashMap<Principal, User>(0, Principal.equal, Principal.hash);
  private let messages = HashMap.HashMap<Nat, Message>(0, Nat.equal, Hash.hash);
  private let rooms = HashMap.HashMap<Nat, ChatRoom>(0, Nat.equal, Hash.hash);

  private let userByUsername = TrieMap.TrieMap<Text, Principal>(Text.equal, Text.hash);
  private let userRoomMembership = HashMap.HashMap<Principal, Buffer.Buffer<Nat>>(0, Principal.equal, Principal.hash);
  private let roomMembers = HashMap.HashMap<Nat, Buffer.Buffer<Principal>>(0, Nat.equal, Hash.hash);
  private let messagesByRoom = HashMap.HashMap<Nat, Buffer.Buffer<Nat>>(0, Nat.equal, Hash.hash);

  private let messageRateLimiter = RateLimiter();
  private let onlineUsersCache = TrieMap.TrieMap<Nat, [User]>(Nat.equal, Hash.hash);
  private var lastCacheUpdate : Int = 0;

  // ===========================================================================
  // RATE LIMITER
  // ===========================================================================

  private class RateLimiter() {
    let dailyMessageCount = TrieMap.TrieMap<Principal, (Int, Nat)>(Principal.equal, Principal.hash);
    let lastMessageTime = TrieMap.TrieMap<Principal, Int>(Principal.equal, Principal.hash);
    var lastCleanup : Int = Time.now();

    public func checkRateLimit(userId : Principal) : Bool {
      let now = Time.now();
      cleanupIfNeeded(now);

      if (checkMessageInterval(userId, now)) return true;
      if (checkDailyLimit(userId, now)) return true;

      false
    };

    private func checkMessageInterval(userId : Principal, now : Int) : Bool {
      switch (lastMessageTime.get(userId)) {
        case (?lastTime) if (now - lastTime < RATE_LIMIT_SECONDS * 1_000_000_000) true;
        case _ {
          lastMessageTime.put(userId, now);
          false
        };
      }
    };

    private func checkDailyLimit(userId : Principal, now : Int) : Bool {
      let dayStart = now - (now % (24 * 60 * 60 * 1_000_000_000));

      switch (dailyMessageCount.get(userId)) {
        case (?(lastDay, count)) {
          if (lastDay == dayStart) {
            if (count >= MAX_MESSAGES_PER_USER_PER_DAY) return true;
            dailyMessageCount.put(userId, (dayStart, count + 1));
          } else {
            dailyMessageCount.put(userId, (dayStart, 1));
          };
        };
        case null { dailyMessageCount.put(userId, (dayStart, 1)) };
      };

      false
    };

    private func cleanupIfNeeded(now : Int) {
      if (now - lastCleanup <= 3_600_000_000_000) return;

      cleanupDailyCounts(now);
      cleanupMessageTimes(now);
      lastCleanup := now;
    };

    private func cleanupDailyCounts(now : Int) {
      let dayAgo = now - (24 * 60 * 60 * 1_000_000_000);
      let toRemove = Buffer.Buffer<Principal>(100);

      for ((userId, (lastDay, _)) in dailyMessageCount.entries()) {
        if (lastDay < dayAgo) toRemove.add(userId);
      };

      for (userId in toRemove.vals()) dailyMessageCount.delete(userId);
    };

    private func cleanupMessageTimes(now : Int) {
      let minuteAgo = now - 60_000_000_000;
      let toRemove = Buffer.Buffer<Principal>(100);

      for ((userId, time) in lastMessageTime.entries()) {
        if (time < minuteAgo) toRemove.add(userId);
      };

      for (userId in toRemove.vals()) lastMessageTime.delete(userId);
    };
  };

  // ===========================================================================
  // SYSTEM FUNCTIONS
  // ===========================================================================

  system func preupgrade() {
    stableUsers := Iter.toArray(users.entries());
    stableMessages := Iter.toArray(messages.entries());
    stableRooms := Iter.toArray(rooms.entries());

    stableUserRoomMembership := Iter.toArray(userRoomMembership.entries()
      .map(func ((p, b) : (Principal, Buffer.Buffer<Nat>)) : (Principal, [Nat]) { (p, Buffer.toArray(b)) }));

    stableRoomMembers := Iter.toArray(roomMembers.entries()
      .map(func ((roomId, b) : (Nat, Buffer.Buffer<Principal>)) : (Nat, [Principal]) { (roomId, Buffer.toArray(b)) }));

    stableMessagesByRoom := Iter.toArray(messagesByRoom.entries()
      .map(func ((roomId, b) : (Nat, Buffer.Buffer<Nat>)) : (Nat, [Nat]) { (roomId, Buffer.toArray(b)) }));
  };

  system func postupgrade() {
    loadStableData();
  };

  private func loadStableData() {
    for ((id, user) in stableUsers.vals()) {
      users.put(id, user);
      userByUsername.put(user.username, user.id);
    };

    for ((id, message) in stableMessages.vals()) messages.put(id, message);
    for ((id, room) in stableRooms.vals()) rooms.put(id, room);

    for ((p, arr) in stableUserRoomMembership.vals()) {
      userRoomMembership.put(p, Buffer.fromArray<Nat>(arr));
    };

    for ((roomId, arr) in stableRoomMembers.vals()) {
      roomMembers.put(roomId, Buffer.fromArray<Principal>(arr));
    };

    for ((roomId, arr) in stableMessagesByRoom.vals()) {
      messagesByRoom.put(roomId, Buffer.fromArray<Nat>(arr));
    };
  };

  // ===========================================================================
  // UTILITY FUNCTIONS
  // ===========================================================================

  private func now() : Int = Time.now();

  private func isValidUsername(username : Text) : Bool {
    let size = Text.size(username);
    size >= 3 and size <= 30
    and Text.matches(username, #regex "^[a-zA-Z0-9_]+$")
  };

  private func isValidDisplayName(name : Text) : Bool {
    let size = Text.size(name);
    size > 0 and size <= MAX_DISPLAY_NAME_LENGTH
    and not Text.contains(name, #char '@')
    and not Text.contains(name, #char '/')
  };

  // FIX: added validation for room name/description (previously createRoom
  // accepted empty or arbitrarily long names with no checks at all).
  private func isValidRoomName(name : Text) : Bool {
    let size = Text.size(name);
    size > 0 and size <= MAX_ROOM_NAME_LENGTH
  };

  private func isValidRoomDescription(description : ?Text) : Bool {
    switch (description) {
      case null true;
      case (?d) Text.size(d) <= MAX_ROOM_DESCRIPTION_LENGTH;
    }
  };

  private func isAdmin(userId : Principal) : Bool {
    switch (users.get(userId)) {
      case (?user) user.role == #Admin or user.role == #Owner;
      case null false;
    }
  };

  private func isModOrAdmin(userId : Principal) : Bool {
    switch (users.get(userId)) {
      case (?user) user.role == #Admin or user.role == #Moderator or user.role == #Owner;
      case null false;
    }
  };

  private func isBanned(userId : Principal) : Bool {
    switch (users.get(userId)) {
      case (?user) {
        switch (user.bannedUntil) {
          case (?until) user.banned and until > now();
          case null user.banned;
        }
      };
      case null false;
    }
  };

  // FIX: strip common trailing punctuation so "@bob," or "@bob." resolve
  // to the username "bob" instead of failing to match anyone.
  private func stripTrailingPunctuation(word : Text) : Text {
    var result = word;
    let punctuation = [',', '.', '!', '?', ':', ';'];
    label trimming loop {
      var trimmedOne = false;
      for (p in punctuation.vals()) {
        if (Text.endsWith(result, #char p)) {
          result := Text.trimEnd(result, #char p);
          trimmedOne := true;
        };
      };
      if (not trimmedOne) break trimming;
    };
    result
  };

  private func extractMentions(text : Text) : [Principal] {
    let words = Text.split(text, #char ' ');
    let mentions = Buffer.Buffer<Principal>(5);

    for (word in words) {
      if (Text.startsWith(word, #text "@")) {
        let username = stripTrailingPunctuation(Text.trimStart(word, #char '@'));
        switch (userByUsername.get(username)) {
          case (?userId) mentions.add(userId);
          case null {};
        };
      };
    };

    Buffer.toArray(mentions)
  };

  private func updateUser(userId : Principal, updateFn : User -> User) {
    switch (users.get(userId)) {
      case (?user) {
        let updated = updateFn(user);
        users.put(userId, updated);
        if (user.username != updated.username) {
          userByUsername.delete(user.username);
          userByUsername.put(updated.username, userId);
        };
      };
      case null {};
    };
  };

  private func incrementMessageCount(userId : Principal) {
    updateUser(userId, func(user) {
      { user with
        messageCount = user.messageCount + 1;
        lastSeen = now();
      }
    });
  };

  private func updateRoomActivity(roomId : Nat) {
    switch (rooms.get(roomId)) {
      case (?room) {
        rooms.put(roomId, {
          room with
          messageCount = room.messageCount + 1;
          lastActivity = now();
        });
      };
      case null {};
    };
  };

  private func periodicCleanup() {
    let cutoff = now() - (MESSAGE_RETENTION_DAYS * 24 * 60 * 60 * 1_000_000_000);

    for ((id, msg) in messages.entries()) {
      if (msg.timestamp < cutoff and not msg.pinned) {
        messages.delete(id);
      };
    };
  };

  private func getOrCreateBuffer<K, V>(
    map : HashMap.HashMap<K, Buffer.Buffer<V>>,
    key : K,
    capacity : Nat
  ) : Buffer.Buffer<V> {
    switch (map.get(key)) {
      case (?buffer) buffer;
      case null {
        let buffer = Buffer.Buffer<V>(capacity);
        map.put(key, buffer);
        buffer
      };
    }
  };

  // ===========================================================================
  // USER MANAGEMENT
  // ===========================================================================

  public shared ({ caller }) func registerUser(
    username : Text,
    displayName : Text,
    bio : ?Text
  ) : async Result<User, Error> {

    if (not isValidUsername(username) or not isValidDisplayName(displayName)) {
      return #err(#InvalidInput);
    };

    if (users.get(caller) != null) {
      return #err(#AlreadyExists);
    };

    if (userByUsername.get(username) != null) {
      return #err(#AlreadyExists);
    };

    let nowTime = now();
    let role = if (users.size() == 0) #Owner else #User;

    let user : User = {
      id = caller;
      displayName = displayName;
      username = username;
      bio = bio;
      avatar = null;
      role = role;
      banned = false;
      bannedUntil = null;
      lastSeen = nowTime;
      status = #Online;
      joined = nowTime;
      messageCount = 0;
      reputation = 0;
      preferences = {
        theme = "dark";
        notifications = true;
        language = "en";
        autoDeleteDMs = false;
        showReadReceipts = true;
      };
      isVerified = false;
    };

    users.put(caller, user);
    userByUsername.put(username, caller);

    #ok(user)
  };

  public shared ({ caller }) func updateProfile(
    newDisplayName : ?Text,
    newUsername : ?Text,
    newBio : ?Text,
    newAvatar : ?Text,
    newStatus : ?UserStatus,
    newPreferences : ?UserPreferences
  ) : async Result<User, Error> {

    switch (users.get(caller)) {
      case null #err(#NotFound);
      case (?user) {
        if (isBanned(caller)) return #err(#Banned);

        let usernameResult = validateNewUsername(user.username, newUsername);
        if (not usernameResult.valid) return #err(usernameResult.error);

        let displayNameResult = validateDisplayName(newDisplayName);
        if (not displayNameResult.valid) return #err(displayNameResult.error);

        let updatedUser = createUpdatedUser(
          user,
          displayNameResult.value,
          usernameResult.value,
          newBio,
          newAvatar,
          newStatus,
          newPreferences
        );

        updateUser(caller, func(_) { updatedUser });
        #ok(updatedUser)
      };
    }
  };

  private func validateNewUsername(
    currentUsername : Text,
    newUsername : ?Text
  ) : { valid : Bool; error : Error; value : Text } {
    switch (newUsername) {
      case null { { valid = true; error = #InvalidInput; value = currentUsername } };
      case (?username) {
        if (not isValidUsername(username)) {
          { valid = false; error = #InvalidInput; value = "" };
        } else if (username != currentUsername and userByUsername.get(username) != null) {
          { valid = false; error = #AlreadyExists; value = "" };
        } else {
          { valid = true; error = #InvalidInput; value = username };
        };
      };
    }
  };

  private func validateDisplayName(
    newDisplayName : ?Text
  ) : { valid : Bool; error : Error; value : Text } {
    switch (newDisplayName) {
      case null { { valid = true; error = #InvalidInput; value = "" } };
      case (?name) {
        if (not isValidDisplayName(name)) {
          { valid = false; error = #InvalidInput; value = "" };
        } else {
          { valid = true; error = #InvalidInput; value = name };
        };
      };
    }
  };

  private func createUpdatedUser(
    user : User,
    displayName : Text,
    username : Text,
    bio : ?Text,
    avatar : ?Text,
    status : ?UserStatus,
    preferences : ?UserPreferences
  ) : User {
    {
      user with
      displayName = displayName;
      username = username;
      bio = Option.get(bio, user.bio);
      avatar = Option.get(avatar, user.avatar);
      status = Option.get(status, user.status);
      preferences = Option.get(preferences, user.preferences);
      lastSeen = now();
    }
  };

  public query func searchUsers(
    query : Text,
    limit : Nat,
    offset : Nat
  ) : async [User] {

    if (query == "") {
      return paginateArray(Iter.toArray(users.vals()), limit, offset);
    };

    let lowerQuery = Text.map(query, Prim.charToLower);
    let results = Buffer.Buffer<User>(limit);
    var count : Nat = 0;

    for (user in users.vals()) {
      if (matchesUserQuery(user, lowerQuery)) {
        if (count >= offset and results.size() < limit) {
          results.add(user);
        };
        count += 1;
      };
    };

    Buffer.toArray(results)
  };

  private func matchesUserQuery(user : User, query : Text) : Bool {
    Text.contains(Text.map(user.username, Prim.charToLower), #text query)
    or Text.contains(Text.map(user.displayName, Prim.charToLower), #text query)
  };

  private func paginateArray<T>(array : [T], limit : Nat, offset : Nat) : [T] {
    let start = Nat.min(offset, array.size());
    let end = Nat.min(start + limit, array.size());
    Array.tabulate(end - start, func(i) { array[start + i] })
  };

  public query func getUser(principalOrUsername : Text) : async ?User {
    switch (Principal.fromText(principalOrUsername)) {
      case (?principal) users.get(principal);
      case null {
        switch (userByUsername.get(principalOrUsername)) {
          case (?principal) users.get(principal);
          case null null;
        };
      };
    }
  };

  // ===========================================================================
  // ROOM MANAGEMENT
  // ===========================================================================

  public shared ({ caller }) func createRoom(
    name : Text,
    description : ?Text,
    roomType : ChatRoomType,
    icon : ?Text,
    rules : ?Text,
    maxMembers : ?Nat
  ) : async Result<ChatRoom, Error> {

    if (isBanned(caller)) return #err(#Banned);

    // FIX: room name/description were previously never validated.
    if (not isValidRoomName(name)) return #err(#InvalidInput);
    if (not isValidRoomDescription(description)) return #err(#InvalidInput);

    let roomId = nextRoomId;
    nextRoomId += 1;

    let room = createRoomObject(roomId, name, description, roomType, icon, rules, maxMembers, caller);
    rooms.put(roomId, room);

    addUserToRoom(caller, roomId);
    #ok(room)
  };

  private func createRoomObject(
    id : Nat,
    name : Text,
    description : ?Text,
    roomType : ChatRoomType,
    icon : ?Text,
    rules : ?Text,
    maxMembers : ?Nat,
    creator : Principal
  ) : ChatRoom {
    let nowTime = now();
    {
      id = id;
      name = name;
      description = description;
      roomType = roomType;
      moderators = [creator];
      createdBy = creator;
      createdAt = nowTime;
      messageCount = 0;
      isArchived = false;
      lastActivity = nowTime;
      icon = icon;
      rules = rules;
      maxMembers = maxMembers;
    }
  };

  // FIX (critical): this used to unconditionally run
  //   messagesByRoom.put(roomId, Buffer.Buffer<Nat>(100))
  // which wiped every existing message reference for the room *every time
  // any user joined it*. Now the buffer is only created if absent, and
  // membership buffers are de-duplicated so repeated joins are harmless.
  private func addUserToRoom(userId : Principal, roomId : Nat) {
    let userBuffer = getOrCreateBuffer(userRoomMembership, userId, 5);
    if (not Buffer.contains(userBuffer, roomId, Nat.equal)) {
      userBuffer.add(roomId);
    };

    let roomBuffer = getOrCreateBuffer(roomMembers, roomId, 10);
    if (not Buffer.contains(roomBuffer, userId, Principal.equal)) {
      roomBuffer.add(userId);
    };

    // Ensure a message list exists for this room without ever clobbering
    // messages that are already there.
    ignore getOrCreateBuffer(messagesByRoom, roomId, 100);
  };

  public shared ({ caller }) func joinRoom(roomId : Nat) : async Result<Bool, Error> {
    switch (rooms.get(roomId)) {
      case null #err(#NotFound);
      case (?room) {
        if (room.isArchived) return #err(#InvalidInput);
        if (isBanned(caller)) return #err(#Banned);
        if (hasRoomAccess(caller, roomId)) return #ok(true); // already a member
        if (isRoomFull(roomId, room.maxMembers)) return #err(#RoomFull);
        if (room.roomType == #Private) return #err(#NoPermission); // Needs invite system

        addUserToRoom(caller, roomId);
        #ok(true)
      };
    }
  };

  private func isRoomFull(roomId : Nat, maxMembers : ?Nat) : Bool {
    switch (maxMembers, roomMembers.get(roomId)) {
      case (?max, ?members) members.size() >= max;
      case _ false;
    }
  };

  public query func getRooms(
    roomType : ?ChatRoomType,
    limit : Nat,
    offset : Nat
  ) : async [ChatRoom] {

    let filteredRooms = Buffer.Buffer<ChatRoom>(limit);
    var count : Nat = 0;

    for (room in rooms.vals()) {
      if (shouldSkipRoom(room, roomType)) continue;

      if (count >= offset and filteredRooms.size() < limit) {
        filteredRooms.add(room);
      };
      count += 1;
    };

    Buffer.toArray(filteredRooms)
  };

  private func shouldSkipRoom(room : ChatRoom, roomType : ?ChatRoomType) : Bool {
    room.isArchived
    or switch (roomType) {
      case (?typeFilter) room.roomType != typeFilter;
      case null false;
    }
  };

  // ===========================================================================
  // MESSAGE MANAGEMENT
  // ===========================================================================

  public shared ({ caller }) func sendMessage(
    content : Text,
    roomId : Nat,
    replyTo : ?Nat,
    messageType : MessageType,
    poll : ?Poll,
    metadata : ?Blob
  ) : async Result<Message, Error> {

    // FIX: room-access is now checked *before* the rate limiter is
    // consulted/updated, so a request that was always going to be rejected
    // (wrong room) no longer burns the caller's rate-limit budget.
    if (isBanned(caller)) return #err(#Banned);
    if (Text.size(content) == 0 or Text.size(content) > MAX_MESSAGE_LENGTH) return #err(#MessageTooLong);
    if (not hasRoomAccess(caller, roomId)) return #err(#NoPermission);
    if (messageRateLimiter.checkRateLimit(caller)) return #err(#RateLimited);

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

    if (Text.size(newContent) == 0 or Text.size(newContent) > MAX_MESSAGE_LENGTH) {
      return #err(#MessageTooLong);
    };

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
    and not message.deleted
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
        let collected = collectMessages(messageIds, actualLimit, before);
        Buffer.toArray(collected)
      };
    }
  };

  // FIX (critical): the previous version iterated with
  //   var idx : Nat; while (idx >= 0) { ...; idx -= 1 }
  // `idx >= 0` is always true for a Nat, so once idx reached 0 the next
  // `idx -= 1` underflowed and trapped the call. Rewritten to stop safely
  // at index 0 using a loop-continuation flag instead of relying on
  // Nat comparisons against zero.
  private func collectMessages(
    messageIds : Buffer.Buffer<Nat>,
    limit : Nat,
    before : ?Nat
  ) : Buffer.Buffer<Message> {
    let results = Buffer.Buffer<Message>(limit);
    let size = messageIds.size();
    if (size == 0 or limit == 0) return results;

    switch (findStartIndex(messageIds, size, before)) {
      case null {}; // "before" message was the oldest one — nothing further back
      case (?startIdx) {
        var idx = startIdx;
        var count = 0;
        var keepGoing = true;

        while (keepGoing and count < limit) {
          addMessageIfValid(messageIds.get(idx), results);
          count += 1;

          if (idx == 0) {
            keepGoing := false;
          } else {
            idx -= 1;
          };
        };
      };
    };

    results
  };

  // FIX: returns `?Nat` now. `null` means "there is nothing older than
  // `before`" (previously represented, incorrectly, as index 0 — which
  // meant the very message being paged from could be re-included).
  private func findStartIndex(
    messageIds : Buffer.Buffer<Nat>,
    size : Nat,
    before : ?Nat
  ) : ?Nat {
    switch (before) {
      case (?msgId) {
        var foundAt : ?Nat = null;
        label search for (i in Iter.range(0, size - 1)) {
          if (messageIds.get(i) == msgId) {
            foundAt := ?i;
            break search;
          };
        };
        switch (foundAt) {
          case (?i) if (i == 0) null else ?(i - 1);
          case null ?(size - 1); // "before" id not found — default to newest
        };
      };
      case null ?(size - 1);
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
    let currentTime = Time.now();

    if (shouldUseCache(roomId, currentTime)) {
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

    let result = calculateOnlineUsers(roomId, currentTime);

    updateCache(roomId, result, currentTime);
    result
  };

  private func shouldUseCache(roomId : ?Nat, currentTime : Int) : Bool {
    currentTime - lastCacheUpdate < CACHE_TTL
  };

  private func calculateOnlineUsers(roomId : ?Nat, currentTime : Int) : [User] {
    let results = Buffer.Buffer<User>(50);

    for (user in users.vals()) {
      if (user.banned) continue;
      if (not isUserOnline(user, currentTime)) continue;
      if (not isUserInRoom(user, roomId)) continue;

      results.add(user);
    };

    Buffer.toArray(results)
  };

  private func isUserOnline(user : User, currentTime : Int) : Bool {
    (currentTime - user.lastSeen) < ONLINE_THRESHOLD
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

  private func updateCache(roomId : ?Nat, cachedUsers : [User], currentTime : Int) {
    lastCacheUpdate := currentTime;
    switch (roomId) {
      case (?id) onlineUsersCache.put(id, cachedUsers);
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

  // FIX: previously sorted ascending and then sliced the first `limit`
  // entries, which returned the *lowest* posting users, not the top
  // posters. The comparator is now inverted to sort descending by count.
  private func getTopPosters(
    userMessageCounts : TrieMap.TrieMap<Principal, Nat>,
    limit : Nat
  ) : [(Principal, Nat)] {
    let entries = Iter.toArray(userMessageCounts.entries());
    let sorted = Array.sort(entries, func(a : (Principal, Nat), b : (Principal, Nat)) : Order.Order {
      if (a.1 > b.1) #less else if (a.1 < b.1) #greater else #equal
    });

    if (sorted.size() > limit) Array.subArray(sorted, 0, limit) else sorted
  };

  public query func version() : async Text {
    "ChatChain v5.3.0"
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
      version = "5.3.0";
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
    if (messagesToSend.size() == 0) return #err(#InvalidInput);

    // FIX: previously used bare `assert`, which traps the entire call with
    // no error information if any single message in the batch is invalid.
    // Now returns a proper typed Result instead.
    switch (validateBatch(messagesToSend, caller)) {
      case (#err(e)) return #err(e);
      case (#ok(_)) {};
    };

    let results = Buffer.Buffer<Message>(messagesToSend.size());
    for (msg in messagesToSend.vals()) {
      let result = createAndStoreMessage(msg, caller);
      results.add(result);
    };

    #ok(Buffer.toArray(results))
  };

  private func validateBatch(
    msgsToValidate : [{ content : Text; roomId : Nat }],
    caller : Principal
  ) : Result<(), Error> {
    for (msg in msgsToValidate.vals()) {
      if (Text.size(msg.content) == 0 or Text.size(msg.content) > MAX_MESSAGE_LENGTH) {
        return #err(#MessageTooLong);
      };
      if (not hasRoomAccess(caller, msg.roomId)) {
        return #err(#NoPermission);
      };
    };
    #ok(())
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

