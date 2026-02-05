trigger ContentDocLinkTrigger on ContentDocumentLink (before insert) {
   AttachmentRelinker.linkAttachmentsToCaseAndAccount(Trigger.new);
}