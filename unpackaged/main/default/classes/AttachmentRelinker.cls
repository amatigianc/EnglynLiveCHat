public with sharing class AttachmentRelinker {

    public static void linkAttachmentsToCaseAndAccount(List<ContentDocumentLink> newLinks) {
        if (newLinks == null || newLinks.isEmpty()) {
            return;
        }

        // Collect LinkedEntityIds (potential MessagingSession ids) and ContentDocumentIds
        Set<Id> linkedEntityIds = new Set<Id>();
        Set<Id> contentDocIds = new Set<Id>();
        for (ContentDocumentLink cdl : newLinks) {
            if (cdl.LinkedEntityId != null && cdl.ContentDocumentId != null) {
                linkedEntityIds.add(cdl.LinkedEntityId);
                contentDocIds.add(cdl.ContentDocumentId);
            }
        }
        if (linkedEntityIds.isEmpty() || contentDocIds.isEmpty()) {
            return;
        }

        // 1) Get the MessagingSession records that match those LinkedEntityIds
        Map<Id, MessagingSession> sessionMap = new Map<Id, MessagingSession>(
            [SELECT Id, CaseId, Case.AccountId
             FROM MessagingSession
             WHERE Id IN :linkedEntityIds]
        );

        if (sessionMap.isEmpty()) {
            return;
        }

        // 2) Collect CaseIds from the sessions (only cases we actually need)
        Set<Id> caseIds = new Set<Id>();
        for (MessagingSession ms : sessionMap.values()) {
            if (ms.CaseId != null) {
                caseIds.add(ms.CaseId);
            }
        }
        if (caseIds.isEmpty()) {
            return;
        }

        // 3) Query cases to get AccountId
        Map<Id, Case> caseMap = new Map<Id, Case>(
            [SELECT Id, AccountId
             FROM Case
             WHERE Id IN :caseIds]
        );

        // 4) Build set of target record ids (cases + accounts) to check for existing links
        Set<Id> targetIds = new Set<Id>();
        targetIds.addAll(caseMap.keySet());
        for (Case c : caseMap.values()) {
            if (c.AccountId != null) {
                targetIds.add(c.AccountId);
            }
        }

        // 5) Query existing ContentDocumentLink records for these content doc ids and target ids
        Set<String> existingLinks = new Set<String>(); // store as "ContentDocumentId-LinkedEntityId"
        if (!targetIds.isEmpty()) {
            for (ContentDocumentLink existing : [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :contentDocIds
                AND LinkedEntityId IN :targetIds
            ]) {
                existingLinks.add(String.valueOf(existing.ContentDocumentId) + '-' + String.valueOf(existing.LinkedEntityId));
            }
        }

        // 6) Prepare new ContentDocumentLink records (avoid duplicates and duplicates within this transaction)
        List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();
        Set<String> willInsertKeys = new Set<String>();

        for (ContentDocumentLink incoming : newLinks) {
            MessagingSession ms = sessionMap.get(incoming.LinkedEntityId);
            if (ms == null || ms.CaseId == null) {
                continue;
            }

            Id caseId = ms.CaseId;
            // Link to Case
            String keyCase = String.valueOf(incoming.ContentDocumentId) + '-' + String.valueOf(caseId);
            if (!existingLinks.contains(keyCase) && !willInsertKeys.contains(keyCase)) {
                toInsert.add(new ContentDocumentLink(
                    ContentDocumentId = incoming.ContentDocumentId,
                    LinkedEntityId = caseId,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ));
                willInsertKeys.add(keyCase);
            }

            // Link to Account (if present)
            Case c = caseMap.get(caseId);
            if (c != null && c.AccountId != null) {
                String keyAccount = String.valueOf(incoming.ContentDocumentId) + '-' + String.valueOf(c.AccountId);
                if (!existingLinks.contains(keyAccount) && !willInsertKeys.contains(keyAccount)) {
                    toInsert.add(new ContentDocumentLink(
                        ContentDocumentId = incoming.ContentDocumentId,
                        LinkedEntityId = c.AccountId,
                        ShareType = 'V',
                        Visibility = 'AllUsers'
                    ));
                    willInsertKeys.add(keyAccount);
                }
            }
        }

        // 7) Insert the new links
        if (!toInsert.isEmpty()) {
            try {
                insert toInsert;
            } catch (DmlException ex) {
                // Optional: log or handle partial failures
                // For production, consider a more robust retry/logging approach
                System.debug('AttachmentRelinker DML exception: ' + ex.getMessage());
                throw ex;
            }
        }
    }
}