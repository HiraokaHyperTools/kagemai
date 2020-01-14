#
# version.rb
#
#   Copyright (C) Ueno Katsuhiro 2001
#
# $Id: version.rb,v 1.1.2.1 2001/05/02 13:29:18 katsu Exp $
#

module XMLScan

  ####==begin XMLSCAN_VERSION
  VERSION = '@@LAST_RELEASE_VERSION: 0.0.10 @@'[23..-3] +
    '-rev' + '$Revision: 1.1.2.1 $ '[11..-4]
  RELEASE_DATE = '$Date: 2001/05/02 13:29:18 $ '[7..-4].instance_eval {
    (Time.gm(*split(/[\/ :]/n)) + 9 * 3600).strftime('%Y-%m-%d')  # in JST
  }
  #: VERSION = '@@VERSION@@'
  #: RELEASE_DATE = '@@RELEASE_DATE@@'
  ####==end XMLSCAN_VERSION

end
