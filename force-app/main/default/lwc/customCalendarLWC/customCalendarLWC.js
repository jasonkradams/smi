import { LightningElement, track, api } from "lwc"
import { ShowToastEvent } from "lightning/platformShowToastEvent"
import getCalendars from "@salesforce/apex/CalendarController.getCalendars"
import getEvents from "@salesforce/apex/CalendarController.getEvents"
import createEvent from "@salesforce/apex/CalendarController.createEvent"

export default class CustomCalendar extends LightningElement {
  @track calendarDays = []
  @track monthNames = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ]
  @track dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  @track currentMonth
  @track currentYear
  @track currentMonthName
  @track events = []
  @track calendars = []
  @track selectedCalendarIds = []
  @track isLoading = true
  @track showNewEventModal = false
  @track newEvent = {
    title: "",
    startDate: null,
    endDate: null,
    calendarId: "",
  }
  @track selectedDate = null
  @track isLocalDev = false
  @api calendarTitle;

  // Getter for calendar options to use in the combobox
  get calendarOptions() {
    return this.calendars.map((calendar) => {
      return {
        label: calendar.name,
        value: calendar.id,
      }
    })
  }

  @api
  get recordId() {
    return this._recordId
  }
  set recordId(value) {
    this._recordId = value
  }

  connectedCallback() {
    const today = new Date()
    this.currentMonth = today.getMonth()
    this.currentYear = today.getFullYear()

    // Check if we're in local development environment
    this.checkIfLocalDev()
    this.loadCalendars()
  }

  checkIfLocalDev() {
    // Simple check to see if we're in local development
    this.isLocalDev = window.location.hostname.includes("localhost") || window.location.hostname.includes("127.0.0.1")
  }

  loadCalendars() {
    this.isLoading = true

    if (this.isLocalDev) {
      // Use mock data for local development
      this.handleMockCalendars()
      return
    }

    getCalendars()
      .then((result) => {
        this.calendars = result
        // By default, select all calendars
        this.selectedCalendarIds = this.calendars.map((cal) => cal.id)
        this.generateCalendarDays()
        this.loadEvents()
      })
      .catch((error) => {
        console.error("Error loading calendars:", error)
        this.showToast("Error", "Error loading calendars: " + this.reduceErrors(error), "error")
        this.isLoading = false

        // Fallback to mock data if there's an error
        this.handleMockCalendars()
      })
  }

  handleMockCalendars() {
    // Mock calendar data for local development or fallback
    this.calendars = [
      { id: "cal1", name: "Work Calendar", color: "#1589EE", style: "background-color: #1589EE" },
      { id: "cal2", name: "Personal Calendar", color: "#4BC076", style: "background-color: #4BC076" },
      { id: "cal3", name: "Team Calendar", color: "#F88962", style: "background-color: #F88962" },
    ]

    // By default, select all calendars
    this.selectedCalendarIds = this.calendars.map((cal) => cal.id)
    this.generateCalendarDays()
    this.loadEvents()
  }

  loadEvents() {
    this.isLoading = true

    // Calculate the first and last day to display in the calendar
    const firstDay = new Date(this.currentYear, this.currentMonth, 1)
    const lastDay = new Date(this.currentYear, this.currentMonth + 1, 0)

    // Add buffer days to include events from previous and next months that are visible
    const startDate = new Date(firstDay)
    startDate.setDate(startDate.getDate() - 7) // One week before

    const endDate = new Date(lastDay)
    endDate.setDate(endDate.getDate() + 7) // One week after

    if (this.isLocalDev) {
      // Use mock data for local development
      this.handleMockEvents(startDate, endDate)
      return
    }

    getEvents({
      startDate: this.formatDate(startDate),
      endDate: this.formatDate(endDate),
      calendarIds: this.selectedCalendarIds,
    })
      .then((result) => {
        this.events = result.map((event) => ({
          ...event,
          date: new Date(event.startDate),
          style: `background-color: ${event.color}; color: white;`,
        }))
        this.addEventsToCalendarDays()
        this.isLoading = false
      })
      .catch((error) => {
        console.error("Error loading events:", error)
        this.showToast("Error", "Error loading events: " + this.reduceErrors(error), "error")
        this.isLoading = false

        // Fallback to mock data if there's an error
        this.handleMockEvents(startDate, endDate)
      })
  }

  handleMockEvents(startDate, endDate) {
    // Mock event data for local development or fallback
    const mockEvents = []

    if (this.selectedCalendarIds.includes("cal1")) {
      mockEvents.push(
        {
          id: "evt1",
          title: "Team Meeting",
          startDate: new Date(this.currentYear, this.currentMonth, 5),
          endDate: new Date(this.currentYear, this.currentMonth, 5),
          calendarId: "cal1",
          calendarName: "Work Calendar",
          color: "#1589EE",
          date: new Date(this.currentYear, this.currentMonth, 5),
          style: "background-color: #1589EE; color: white;",
        },
        {
          id: "evt2",
          title: "Project Review",
          startDate: new Date(this.currentYear, this.currentMonth, 12),
          endDate: new Date(this.currentYear, this.currentMonth, 12),
          calendarId: "cal1",
          calendarName: "Work Calendar",
          color: "#1589EE",
          date: new Date(this.currentYear, this.currentMonth, 12),
          style: "background-color: #1589EE; color: white;",
        },
      )
    }

    if (this.selectedCalendarIds.includes("cal2")) {
      mockEvents.push(
        {
          id: "evt3",
          title: "Doctor Appointment",
          startDate: new Date(this.currentYear, this.currentMonth, 8),
          endDate: new Date(this.currentYear, this.currentMonth, 8),
          calendarId: "cal2",
          calendarName: "Personal Calendar",
          color: "#4BC076",
          date: new Date(this.currentYear, this.currentMonth, 8),
          style: "background-color: #4BC076; color: white;",
        },
        {
          id: "evt4",
          title: "Gym Session",
          startDate: new Date(this.currentYear, this.currentMonth, 15),
          endDate: new Date(this.currentYear, this.currentMonth, 15),
          calendarId: "cal2",
          calendarName: "Personal Calendar",
          color: "#4BC076",
          date: new Date(this.currentYear, this.currentMonth, 15),
          style: "background-color: #4BC076; color: white;",
        },
      )
    }

    if (this.selectedCalendarIds.includes("cal3")) {
      mockEvents.push(
        {
          id: "evt5",
          title: "Sprint Planning",
          startDate: new Date(this.currentYear, this.currentMonth, 3),
          endDate: new Date(this.currentYear, this.currentMonth, 3),
          calendarId: "cal3",
          calendarName: "Team Calendar",
          color: "#F88962",
          date: new Date(this.currentYear, this.currentMonth, 3),
          style: "background-color: #F88962; color: white;",
        },
        {
          id: "evt6",
          title: "Team Building",
          startDate: new Date(this.currentYear, this.currentMonth, 18),
          endDate: new Date(this.currentYear, this.currentMonth, 18),
          calendarId: "cal3",
          calendarName: "Team Calendar",
          color: "#F88962",
          date: new Date(this.currentYear, this.currentMonth, 18),
          style: "background-color: #F88962; color: white;",
        },
      )
    }

    this.events = mockEvents
    this.addEventsToCalendarDays()
    this.isLoading = false
  }

  formatDate(date) {
    return date.toISOString().split("T")[0]
  }

  generateCalendarDays() {
    this.calendarDays = []
    this.currentMonthName = this.monthNames[this.currentMonth]

    // Get the first day of the month
    const firstDay = new Date(this.currentYear, this.currentMonth, 1)
    const startingDay = firstDay.getDay()

    // Get the number of days in the month
    const lastDay = new Date(this.currentYear, this.currentMonth + 1, 0)
    const monthLength = lastDay.getDate()

    // Get the number of days from the previous month to display
    const prevMonthLastDay = new Date(this.currentYear, this.currentMonth, 0).getDate()

    // Create calendar grid with previous month days
    for (let i = 0; i < startingDay; i++) {
      const prevMonthDay = prevMonthLastDay - startingDay + i + 1
      const date = new Date(this.currentYear, this.currentMonth - 1, prevMonthDay)
      this.calendarDays.push({
        day: prevMonthDay,
        isCurrentMonth: false,
        date: date,
        cssClass: "day other-month",
        id: `prev-${this.currentYear}-${this.currentMonth - 1}-${prevMonthDay}`,
        formattedDate: this.formatDateForDisplay(date),
      })
    }

    // Current month days
    const today = new Date()
    const isCurrentMonthAndYear = today.getMonth() === this.currentMonth && today.getFullYear() === this.currentYear

    for (let i = 1; i <= monthLength; i++) {
      const isToday = isCurrentMonthAndYear && i === today.getDate()
      const date = new Date(this.currentYear, this.currentMonth, i)
      this.calendarDays.push({
        day: i,
        isCurrentMonth: true,
        isToday: isToday,
        date: date,
        cssClass: isToday ? "day current-month today" : "day current-month",
        id: `current-${this.currentYear}-${this.currentMonth}-${i}`,
        formattedDate: this.formatDateForDisplay(date),
      })
    }

    // Next month days to fill the grid (6 rows x 7 days = 42 cells)
    const remainingCells = 42 - this.calendarDays.length
    for (let i = 1; i <= remainingCells; i++) {
      const date = new Date(this.currentYear, this.currentMonth + 1, i)
      this.calendarDays.push({
        day: i,
        isCurrentMonth: false,
        date: date,
        cssClass: "day other-month",
        id: `next-${this.currentYear}-${this.currentMonth + 1}-${i}`,
        formattedDate: this.formatDateForDisplay(date),
      })
    }
  }

  formatDateForDisplay(date) {
    return date.toLocaleDateString("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
      year: "numeric",
    })
  }

  addEventsToCalendarDays() {
    if (this.events && this.events.length > 0) {
      this.calendarDays = this.calendarDays.map((day) => {
        const dayEvents = this.events.filter((event) => {
          const eventDate = new Date(event.date)
          return (
            eventDate.getDate() === day.date.getDate() &&
            eventDate.getMonth() === day.date.getMonth() &&
            eventDate.getFullYear() === day.date.getFullYear()
          )
        })

        return {
          ...day,
          events: dayEvents,
          hasEvents: dayEvents.length > 0,
        }
      })
    }
  }

  previousMonth() {
    this.currentMonth--
    if (this.currentMonth < 0) {
      this.currentMonth = 11
      this.currentYear--
    }
    this.generateCalendarDays()
    this.loadEvents()
  }

  nextMonth() {
    this.currentMonth++
    if (this.currentMonth > 11) {
      this.currentMonth = 0
      this.currentYear++
    }
    this.generateCalendarDays()
    this.loadEvents()
  }

  handleDayClick(event) {
    const dayIndex = event.currentTarget.dataset.index
    const selectedDay = this.calendarDays[dayIndex]
    this.selectedDate = selectedDay.date

    // Open the new event modal
    this.openNewEventModal(selectedDay)
  }

  handleCalendarToggle(event) {
    const calendarId = event.target.dataset.id
    const isChecked = event.target.checked

    if (isChecked) {
      // Add calendar to selected list
      if (!this.selectedCalendarIds.includes(calendarId)) {
        this.selectedCalendarIds.push(calendarId)
      }
    } else {
      // Remove calendar from selected list
      this.selectedCalendarIds = this.selectedCalendarIds.filter((id) => id !== calendarId)
    }

    // Reload events with the updated calendar selection
    this.loadEvents()
  }

  openNewEventModal(day) {
    // Initialize the new event with the selected date
    this.newEvent = {
      title: "",
      startDate: this.formatDate(day.date),
      endDate: this.formatDate(day.date),
      calendarId: this.selectedCalendarIds.length > 0 ? this.selectedCalendarIds[0] : "",
    }
    this.showNewEventModal = true
  }

  closeNewEventModal() {
    this.showNewEventModal = false
  }

  handleNewEventChange(event) {
    const field = event.target.name
    const value = event.target.value
    this.newEvent = { ...this.newEvent, [field]: value }
  }

  handleSaveEvent() {
    if (!this.validateNewEvent()) {
      return
    }

    this.isLoading = true

    if (this.isLocalDev) {
      // Mock event creation for local development
      setTimeout(() => {
        // Create a mock event and add it to the events array
        const newEventId = "new-" + Date.now()
        const selectedCalendar = this.calendars.find((cal) => cal.id === this.newEvent.calendarId)

        const newEventObj = {
          id: newEventId,
          title: this.newEvent.title,
          startDate: new Date(this.newEvent.startDate),
          endDate: new Date(this.newEvent.endDate),
          calendarId: this.newEvent.calendarId,
          calendarName: selectedCalendar ? selectedCalendar.name : "",
          color: selectedCalendar ? selectedCalendar.color : "#1589EE",
          date: new Date(this.newEvent.startDate),
          style: `background-color: ${selectedCalendar ? selectedCalendar.color : "#1589EE"}; color: white;`,
        }

        this.events.push(newEventObj)
        this.addEventsToCalendarDays()
        this.showToast("Success", "Event created successfully", "success")
        this.closeNewEventModal()
        this.isLoading = false
      }, 500)

      return
    }

    createEvent({
      title: this.newEvent.title,
      startDate: this.newEvent.startDate,
      endDate: this.newEvent.endDate,
      calendarId: this.newEvent.calendarId,
    })
      .then((result) => {
        this.showToast("Success", "Event created successfully", "success")
        this.closeNewEventModal()
        this.loadEvents() // Reload events to include the new one
      })
      .catch((error) => {
        console.error("Error creating event:", error)
        this.showToast("Error", "Error creating event: " + this.reduceErrors(error), "error")
        this.isLoading = false
      })
  }

  validateNewEvent() {
    // Basic validation
    if (!this.newEvent.title || this.newEvent.title.trim() === "") {
      this.showToast("Error", "Please enter an event title", "error")
      return false
    }

    if (!this.newEvent.startDate) {
      this.showToast("Error", "Please select a start date", "error")
      return false
    }

    if (!this.newEvent.endDate) {
      this.showToast("Error", "Please select an end date", "error")
      return false
    }

    if (new Date(this.newEvent.endDate) < new Date(this.newEvent.startDate)) {
      this.showToast("Error", "End date cannot be before start date", "error")
      return false
    }

    if (!this.newEvent.calendarId) {
      this.showToast("Error", "Please select a calendar", "error")
      return false
    }

    return true
  }

  showToast(title, message, variant) {
    const evt = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant,
    })
    this.dispatchEvent(evt)
  }

  reduceErrors(errors) {
    if (!Array.isArray(errors)) {
      errors = [errors]
    }

    return errors
      .filter((error) => !!error)
      .map((error) => {
        // UI API read errors
        if (Array.isArray(error.body)) {
          return error.body.map((e) => e.message).join(", ")
        }
        // UI API DML, Apex and network errors
        else if (error.body && typeof error.body.message === "string") {
          return error.body.message
        }
        // JS errors
        else if (typeof error.message === "string") {
          return error.message
        }
        // Unknown error shape so try HTTP status text
        return error.statusText
      })
      .join(", ")
  }
}

