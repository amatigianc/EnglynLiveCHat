@isTest
private class UnitTestAttachmentRelinker {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Case c = new Case(AccountId = acc.Id, Subject = 'Test Case');
        insert c;
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDocument.txt',
            VersionData = Blob.valueOf('Test content for the document')
        );
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        Id contentDocId = cv.ContentDocumentId;

        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(currentUser) {
            MessagingChannel mc = new MessagingChannel(
                DeveloperName = 'Test_Channel',
                MasterLabel = 'Test Channel',
                IsActive = true,
                MessagingPlatformKey = 'SomeKey',
                MessageType = 'Text'
            );
            insert mc;
            
            MessagingEndUser meu = new MessagingEndUser(
                MessagingChannelId = mc.Id,
                Name = 'Test End User',
                MessagingPlatformKey = 'SomeKey',
                MessageType = 'Text'
            );
            insert meu;
        }

        MessagingChannel mc = [SELECT Id FROM MessagingChannel WHERE DeveloperName = 'Test_Channel' LIMIT 1];
        MessagingEndUser meu = [SELECT Id FROM MessagingEndUser WHERE Name = 'Test End User' LIMIT 1];

        MessagingSession session = new MessagingSession(
            CaseId = c.Id,
            MessagingChannelId = mc.Id,
            MessagingEndUserId = meu.Id,
            Status = 'Ended'
        );
        insert session;
        
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = session.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
    }
    
    @isTest
    static void testLinkAttachmentsToCaseAndAccount_Success() {
        MessagingSession session = [SELECT Id, CaseId FROM MessagingSession LIMIT 1];
        Case c = [SELECT Id, AccountId FROM Case WHERE Id = :session.CaseId];
        ContentVersion cv = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 1];
        Id contentDocId = cv.ContentDocumentId;
        List<ContentDocumentLink> newLinks = [SELECT Id, ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :session.Id];

        Test.startTest();
        AttachmentRelinker.linkAttachmentsToCaseAndAccount(newLinks);
        Test.stopTest();

        List<ContentDocumentLink> allLinks = [SELECT Id, LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE ContentDocumentId = :contentDocId];

        Boolean originalFound = false;
        Boolean caseLinkFound = false;
        Boolean accountLinkFound = false;

        for (ContentDocumentLink link : allLinks) {
            if (link.LinkedEntityId == session.Id) {
                originalFound = true;
            }
            if (link.LinkedEntityId == c.Id) {
                caseLinkFound = true;
            }
            if (c.AccountId != null && link.LinkedEntityId == c.AccountId) {
                accountLinkFound = true;
            }
        }

        System.assert(originalFound, 'Original ContentDocumentLink (to MessagingSession) should exist.');
        System.assert(caseLinkFound, 'A ContentDocumentLink should have been created for the Case.');
        System.assert(accountLinkFound, 'A ContentDocumentLink should have been created for the Account.');
    }

    @isTest
    static void testLinkAttachments_NoCaseId() {
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document No Case',
            PathOnClient = 'TestDocumentNoCase.txt',
            VersionData = Blob.valueOf('Test content')
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        Id contentDocId = cv.ContentDocumentId;
        
        MessagingChannel mc;
        MessagingEndUser meu;
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(currentUser) {
            mc = new MessagingChannel(
                DeveloperName = 'Test_Channel_2',
                MasterLabel = 'Test Channel 2',
                IsActive = true,
                MessagingPlatformKey = 'SomeOtherKey',
                MessageType = 'Text'
            );
            insert mc;
            meu = new MessagingEndUser(
                MessagingChannelId = mc.Id,
                Name = 'Test End User 2',
                MessagingPlatformKey = 'SomeOtherKey',
                MessageType = 'Text'
            );
            insert meu;
        }

        MessagingSession session = new MessagingSession(
            MessagingChannelId = mc.Id,
            MessagingEndUserId = meu.Id,
            Status = 'Ended'
        );
        insert session;
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = session.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        Test.startTest();
        AttachmentRelinker.linkAttachmentsToCaseAndAccount(new List<ContentDocumentLink>{cdl});
        Test.stopTest();

        List<ContentDocumentLink> allLinks = [SELECT Id, LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId = :contentDocId];

        Boolean originalFound = false;
        for (ContentDocumentLink link : allLinks) {
            if (link.LinkedEntityId == session.Id) {
                originalFound = true;
                break;
            }
        }

        System.assert(originalFound, 'Original ContentDocumentLink (to MessagingSession) should exist.');
    }

    @isTest
    static void testLinkAttachments_NoAccountId() {
        Case c = new Case(Subject = 'Test Case No Account');
        insert c;
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document No Account',
            PathOnClient = 'TestDocumentNoAccount.txt',
            VersionData = Blob.valueOf('Test content')
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        Id contentDocId = cv.ContentDocumentId;
        
        MessagingChannel mc;
        MessagingEndUser meu;
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(currentUser) {
            mc = new MessagingChannel(
                DeveloperName = 'Test_Channel_3',
                MasterLabel = 'Test Channel 3',
                IsActive = true,
                MessagingPlatformKey = 'AnotherKey',
                MessageType = 'Text'
            );
            insert mc;
            meu = new MessagingEndUser(
                MessagingChannelId = mc.Id,
                Name = 'Test End User 3',
                MessagingPlatformKey = 'AnotherKey',
                MessageType = 'Text'
            );
            insert meu;
        }

        MessagingSession session = new MessagingSession(
            CaseId = c.Id, 
            MessagingChannelId = mc.Id,
            MessagingEndUserId = meu.Id,
            Status = 'Ended'
        );
        insert session;
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = session.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        Test.startTest();
        AttachmentRelinker.linkAttachmentsToCaseAndAccount(new List<ContentDocumentLink>{cdl});
        Test.stopTest();

        List<ContentDocumentLink> allLinks = [SELECT Id, LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId = :contentDocId];

        Boolean originalFound = false;
        Boolean caseLinkFound = false;

        for (ContentDocumentLink link : allLinks) {
            if (link.LinkedEntityId == session.Id) {
                originalFound = true;
            }
            if (link.LinkedEntityId == c.Id) {
                caseLinkFound = true;
            }
        }

        System.assert(originalFound, 'Original ContentDocumentLink (to MessagingSession) should exist.');
        System.assert(caseLinkFound, 'A ContentDocumentLink should have been created for the Case.');
    }
}