@RestResource(urlMapping='/zohoBouncedLeadGenEmails')
global without sharing class B2B_WS_ZohoBouncedLeadGenEmails {
    private static final String API_KEY {
        get {
            if (API_KEY == null) {
                B2B_Zoho_Settings__mdt settings = B2B_Zoho_Settings__mdt.getInstance('Default');
                API_KEY = settings?.API_Key__c;
            }
            return API_KEY;
        }
        private set;
    }

    @HttpPost
    global static void handlePost() {
        System.debug('****** START B2B_WS_ZohoBouncedLeadGenEmails ******');
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        // --- 1) Auth via Header ---
        String key = req.headers.get('X-API-Key');
        System.debug('key: ' + key);
        if (String.isBlank(key) || key != API_KEY) {
            res.statusCode = 401;
            res.responseBody = Blob.valueOf('Unauthorized');
            return;
        }

        // --- 2) Form-Params direkt nutzen (Salesforce parsed already) ---
        Map<String, String> params = req.params;
        System.debug('params: ' + params);

        String eventType        = params.get('eventType');
        String bounceType       = params.get('bounceType');
        String bouncedEmailRaw  = params.get('bouncedEmail');
        String mailSubject      = params.get('mailSubject');
        String fromAddress      = params.get('fromAddress');
        String zohoMailMessageId= params.get('zohoMailMessageId');

        System.debug('bouncedEmailRaw: ' + bouncedEmailRaw);
        System.debug('bounceType: ' + bounceType);
        System.debug('mailSubject: ' + mailSubject);
        System.debug('fromAddress: ' + fromAddress);
        System.debug('zohoMailMessageId: ' + zohoMailMessageId);

        if (String.isBlank(bouncedEmailRaw)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('Missing bouncedEmail');
            return;
        }

        // --- 3) Erste echte E-Mail aus dem Text ziehen (wegen rfc822 + HTML) ---
        String bouncedEmail = extractFirstEmail(bouncedEmailRaw);
        System.debug('bouncedEmail(clean): ' + bouncedEmail);

        if (String.isBlank(bouncedEmail)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('Could not extract email');
            return;
        }

        // --- 4) Lead finden & updaten ---
        List<Lead> leads = [
            SELECT Id, Email, B2B_TF_EmailError__c
            FROM Lead
            WHERE Email = :bouncedEmail
            LIMIT 1
        ];
        System.debug('leads: ' + leads);

        if (leads.isEmpty()) {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf('Lead not found');
            return;
        }

        Lead l = leads[0];
        l.B2B_CB_BouncedEmailZoho__c = true; // oder bounceType etc.
        l.B2B_TF_EmailStatus__c = 'E-Mail Bounced';
        l.B2B_TF_EmailError__c = 'E-Mail Bounced - Invalid Email Address: ' + bouncedEmail ; // oder bounceType etc.
        update l;

        res.statusCode = 200;
        res.responseBody = Blob.valueOf('OK');
    }

    private static String extractFirstEmail(String text) {
        if (String.isBlank(text)) return null;
        Pattern p = Pattern.compile('[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}');
        Matcher m = p.matcher(text);
        if (m.find()) return m.group(0);
        return null;
    }
    private static void reply(RestResponse res, Integer status, String msg, Map<String, Object> data) {
      res.statusCode = status;
      res.addHeader('Content-Type', 'application/json; charset=UTF-8');

      Map<String, Object> out = new Map<String, Object>();
      out.put('ok', status >= 200 && status < 300);
      out.put('message', msg);
      if (data != null) out.put('data', data);

      res.responseBody = Blob.valueOf(JSON.serialize(out));
   }
}
