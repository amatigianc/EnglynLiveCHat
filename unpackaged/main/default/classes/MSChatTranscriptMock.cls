/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
global class MSChatTranscriptMock implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');

        String body = JSON.serialize(new Map<String,Object>{
            'entries' => new List<Object>{
                new Map<String,Object>{
                    'entryType' => 'Message',
                    'actorType' => 'EndUser',
                    'messageText' => 'Hello',
                    'timestamp' => '2026-05-05T10:00:00Z'
                },
                new Map<String,Object>{
                    'entryType' => 'Message',
                    'actorType' => 'Agent',
                    'actorName' => 'John Doe',
                    'messageText' => 'Hi, how can I help?',
                    'timestamp' => '2026-05-05T10:01:00Z'
                }
            }
        });

        res.setBody(body);
        res.setStatusCode(200);
        return res;
    }
}