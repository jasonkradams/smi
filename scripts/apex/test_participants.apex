List<EventParticipantRedirectHelper.ParticipantWrapper> participants = EventParticipantRedirectHelper.getEventParticipants('a12Um000002MNmPIAW');
System.debug('Found ' + participants.size() + ' participants:');
for(EventParticipantRedirectHelper.ParticipantWrapper p : participants) {
    System.debug('Name: ' + p.contactName + ', HasUser: ' + p.hasUser + ', UserId: ' + p.userId);
}
