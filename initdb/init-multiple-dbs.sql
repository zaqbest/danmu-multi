-- Create databases for danmu-server instances (1/2/3)
-- NOTE: only executed on FIRST initialization (empty data directory)
-- danmuapi1 is auto-created by MYSQL_DATABASE; CREATE IF NOT EXISTS keeps it consistent
CREATE DATABASE IF NOT EXISTS danmuapi1 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS danmuapi2 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS danmuapi3 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant the shared app user access to all three databases
GRANT ALL PRIVILEGES ON danmuapi1.* TO 'danmuapi'@'%';
GRANT ALL PRIVILEGES ON danmuapi2.* TO 'danmuapi'@'%';
GRANT ALL PRIVILEGES ON danmuapi3.* TO 'danmuapi'@'%';
FLUSH PRIVILEGES;
