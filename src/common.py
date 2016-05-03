########################################################################
# common.py -- common functions
#
# Copyright (C) 2015 Andreas Platschek <andi.platschek@gmail.com>
#                    Martin  Mosbeck   <martin.mosbeck@gmx.at>
# License GPL V2 or later (see http://www.gnu.org/licenses/gpl2.txt)
########################################################################

import sqlite3 as lite
import os
import datetime

format_string='%Y-%m-%d %H:%M:%S'

####
# log_a_msg()
####
def log_a_msg(lqueue, lname, msg, loglevel):
   lqueue.put(dict({"msg": msg, "type": loglevel, "loggername": lname}))

####
#   check_dir_mkdir
#
#   returns 0 if the directory already existed, 1 if it had to be created.
####
def check_dir_mkdir(directory, lqueue, lname):
   if not os.path.exists(directory):
      os.mkdir(directory)
      logmsg = "Created directory: " + directory
      log_a_msg(lqueue, lname, logmsg, "DEBUG")
      return 1
   else:
      logmsg = "Directory already exists: " + directory
      log_a_msg(lqueue, lname, logmsg, "WARNING")
      return 0

####
# send_email()
####
def send_email(queue, recipient, userid, messagetype, tasknr, body, messageid):
   queue.put(dict({"recipient": recipient, "UserId": str(userid), "message_type": messagetype, "Task": str(tasknr), "Body": body, "MessageId": messageid}))

####
#  connect_to_db()
####
def connect_to_db(dbname, lqueue, lname):
   # connect to sqlite database ...
   try:
      con = lite.connect(dbname, 120)
   except:
      logmsg = "Failed to connect to database: " + dbname
      log_a_msg(lqueue, lname, logmsg, "ERROR")
      return None, None 

   cur = con.cursor()

   return cur, con

####
# increment_db_statcounter()
####
def increment_db_statcounter(semesterdb, countername, lqueue, lname):
   curs, cons = connect_to_db(semesterdb, lqueue, lname)

   data = {'Name': countername}
   sql_cmd = "UPDATE StatCounters SET Value = (SELECT Value FROM StatCounters WHERE Name == :Name)+1 WHERE Name == :Name"
   curs.execute(sql_cmd, data)
   cons.commit();

   cons.close()


def get_task_starttime(coursedb, tasknr, lqueue, lname):
   curc, conc = connect_to_db(coursedb, lqueue, lname)

   try:
      data = {'TaskNr': tasknr}
      sql_cmd = "SELECT TaskStart FROM TaskConfiguration WHERE TaskNr == :TaskNr"
      curc.execute(sql_cmd, data)
      tstart_string = str(curc.fetchone()[0])
      ret = datetime.datetime.strptime(tstart_string, format_string)
   except:
      ret = datetime.datetime(1970,1,1,0,0,0)

   conc.close()

   return ret


def get_task_deadline(coursedb, tasknr, lqueue, lname):
   curc, conc = connect_to_db(coursedb, lqueue, lname)

   data = {'TaskNr': tasknr}
   sqlcmd = "SELECT TaskDeadline FROM TaskConfiguration WHERE TaskNr == :TaskNr"
   curc.execute(sqlcmd, data)
   deadline_string = str(curc.fetchone()[0])

   conc.close()

   #format_string='%Y-%m-%d %H:%M:%S'
   return datetime.datetime.strptime(deadline_string, format_string)

####
# user_set_currentTask()
#
# Set the currentTask of the user with userid to tasknr.
####
def user_set_currentTask(semesterdb, tasknr, userid, lqueue, lname):
   curs,cons = connect_to_db(semesterdb, lqueue, lname)

   data = {'TaskNr': tasknr, 'UserId': userid}
   sql_cmd = "UPDATE Users SET CurrentTask = :TaskNr WHERE UserId == :UserId"
   curs.execute(sql_cmd, data)
   cons.commit();

   cons.close()


####
# user_get_currentTask()
#
# Get the surrentTask of the user with userid.
####
def user_get_currentTask(semesterdb, userid, lqueue, lname):
   curs,cons = connect_to_db(semesterdb, lqueue, lname)

   data = {'UserId': userid}
   sql_cmd = "SELECT CurrentTask FROM Users WHERE UserId == :UserId"
   curs.execute(sql_cmd, data)
   res = curs.fetchone();

   cons.close()

   return str(res[0]);


####
# get_numTasks()
####
def get_num_Tasks(coursedb, lqueue, lname):
   curc, conc = connect_to_db(coursedb, lqueue, lname)

   sql_cmd = "SELECT Content FROM GeneralConfig WHERE ConfigItem == 'num_tasks'"
   curc.execute(sql_cmd)
   numTasks = int(curc.fetchone()[0])

   conc.close()

   return numTasks
