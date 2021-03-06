#
# This is a Shiny web application creatd by Will Smiles
# You can view my shinyapp here:
#    https://wsmiles000.shinyapps.io/Trump-Tweets-Stock-Pricing/
#

library(shiny)
library(dygraphs)
library(tidyverse)
library(ggplot2)
library(ggthemes)
library(lubridate)
library(tidyquant)
library(quantmod)
library(magrittr)
library(DT)
library(twitteR)
library(QuantTools)
library(timeDate)
library(shinythemes)
library(plotly)


####################################                 
# LOAD DATA
####################################

# Loads previously stored tweet data from tweet_data folder. To update the data with the most up-to-date tweets
# simply run the twitter.R script located in the repository

tweets <- read_rds("tweet_data/trump_tweets.rds")

company <- read_rds("tweet_data/company_tweets.rds")

country <- read_rds("tweet_data/country_tweets.rds")

individual <- read_rds("tweet_data/individual_tweets.rds")

###################################
# USER INTERFACE
###################################

# Define UI for application interface
ui <- navbarPage("Trump's Tweets & The Stock Market", theme = shinytheme("simplex"),
             
   ###################################
   # EXPLORE PAGE
   ###################################

    tabPanel("Explore",

       
      fluidPage(
        
        titlePanel("Effects of President Trump's Tweets on Stock Price and Volume"),
        
        hr(),
      
        sidebarLayout(
          sidebarPanel(
              helpText("Input a Symbol, Date, and Interval to see the stock's pricing"),
              h3("Stock Pricing"),
              
              # Stock Symbol Input - input$symb
              
              textInput("symb", label = "Stock Symbol", value = "MSFT"), 
              
              # Date Input - input$symb 
              # Use floor_date to ensure always start on Monday of most recent week
              
              dateInput('date',
                             label = 'Date Input',
                             min = "2016-01-01", 
                             max = Sys.Date(),
                             value = floor_date(Sys.Date(), unit = "weeks", week_start = 1), 
                             weekstart = 1 
              ),
              
              # Interval Input - input$period (see Quantmod "period" argument")
              
              selectInput("period", "Interval:",
                          c("1 Minute" = "1min",
                            "5 Minutes" = "5min",
                            "30 Minutes" = "30min",
                            "1 Hour" = "hour")),
              br(),
              hr(),
              br(),
              
              h3("Tweet Search"),
              
              # DTable Keyword Input - input$keyword
              
              textInput("keyword", "Please enter a keyword to search, e.g. Amazon", "Amazon")
            
          ),
          
          
          mainPanel(
            
            # Styling for Custom Error Message (instead of red warning)
            
            tags$head(
              tags$style(HTML("
                              .shiny-output-error-validation {
                              font-size: 22px;
                              }
                              "))
              ),
            
            tabsetPanel(
              
                # dygraph Pricing Plot
              
                tabPanel("Pricing", dygraphOutput("price")),
                
                # dygraph Volume Plot
                
                tabPanel("Trade Volume", dygraphOutput("volume"))
                ),
            
            # Tweet DTable Output
            
            DTOutput("word_table")
            
          )
  
        )
        
      )
    ),
    
   ###################################
   # KEY TWEETS PAGE
   ###################################
   
   
    tabPanel("Key Tweets",
          fluidPage(
            titlePanel("Sentiment Analysis by Keywords"),
            
            hr(),
            
            sidebarLayout(
              sidebarPanel(
                helpText("Select a Keyword Type to Explore"),
                h3("Keywords"),
                
                # Select which Keyword Type - input$type - Used for interactvely updating dataframe values
                
                selectInput("type", "Type:",
                            c("Company",
                            "Country",
                            "Individual"))
              ),
              
              mainPanel(
                tabsetPanel(
                  
                  # Positive Sentiment Bar Chart (on its own tab)
                   
                  tabPanel("Positive Sentiment", plotOutput("positive")),
                  
                  # Negative Sentiment Bar Chart (on its own tab)
                  
                  tabPanel("Negative Sentiment", plotOutput("negative"))
                  
                )
              )
            )
      ) 
    ),
   
   ###################################
   # ABOUT PAGE
   ###################################
   
   
   
   tabPanel("About",
            titlePanel(h1("POTUS & PRICING: How Trump's Tweets Affect Intraday Trading", h2(a("@realDonaldTrump",href="https://twitter.com/realDonaldTrump")))),
            
            
            hr(),
            
            # Overview Explanation
            
            h3("Overview"),
            h4("This interface is designed to allow users to explore the relationship between Donald Trump's tweets
               and stock market fluctuations. The dashboard includes an interactive search table for users to browse
               keywords or companies mentioned in Trump's tweets. Then, for select large-cap publicly traded companies, users can input a stock symbol
               and view the intraday price and volume fluctations for that specific company."),
            
            # The br() function adds white space to the app.
            
            
            # Exlore Page Explanation
            
            br(),
            br(),
            h3("Explore Page"), 
            h4("Using a combination of", a("Twitter's API", href="https://developer.twitter.com/" ),"and the", a("QuantTools", href="https://cran.r-project.org/web/packages/QuantTools/QuantTools.pdf"), "library, I was able to pull both Trump's tweets as well intraday financial data since  Trump's inauguration. The Explore Page allows
               users to view the relationships between certain keywords in Trump's tweets and the ensuing changes in stock pricing and volume. Moreover, by clicking on the date column in the tweet table,
               the stock price & volume charts will automatically update to the clicked date. Because not all the financial data is uniformly collected, users can select a different trading interval in
               order to best fit the graph. Should a certain interval appear to have missing values, I'd recommend switching the view period to 30 min for a more complete graph. NOTE: The financial data
               contains most large-cap publicly trade companies, but many large-cap intraday data is still unavailable due to public data limitations."),
            
            br(),
            br(),
            
            # Key Tweets Page Explanation
            
            h3("Key Tweets Page"),
            h4("Finally, the last page acts as a starting point for the data -- detailing a sentiment analysis of relevant keywords within the tweets. Feel free to search these words within the
               explore page and see their effects on different stocks. Keyword sentiments include relevant companies (large-cap), countries (U.S. enemies and allies), and individuals (CEO's and
               Foreign Leaders)"),
            
            br(),
            hr(),
            
            # Repository Link
            
            h4(a("Github Repository", href="https://github.com/wsmiles000/Trumps-Tweets-Stock-Market")),
            br()
            
        )
  )




###################################
# SERVER
###################################


# Define server and client-side logic for interactive visualization
server <- shinyServer(function(input, output, session) {
  
  
  ###################################
  # EXPLORE PAGE 
  ###################################
  
  
  # Event handler to determine if a Tweet Date has been clicked. If a Tweet date is clicked, it updates
  # the DateInput value (input$date) selection. The "if" statement is used to ensures the update  only 
  # takes place if there is anexisting date value and the 1st column was clicked 
  
  observeEvent(input$word_table_cell_clicked, {
    
    # input$word_table_cell_clicked return row index, column index, and value arguments
    
    info = input$word_table_cell_clicked
    
    # do nothing if not clicked yet, or the clicked cell is not in the 1st column
    
    if (is.null(info$value) || info$col != 1) return()
      updateDateInput(session,'date', value = info$value)

  })
  
  # prceInput() function fetches the price data for the given stock symbol. However, we first validate that the 
  # date selected is not a weekend day and that the data exists (!is.null). The same logic applies for
  # volumeInput()
  
  priceInput <- reactive({
    
    shiny::validate(
      need(as.logical(isWeekday(input$date)) == TRUE , "Please select a valid weekday")
    )
    
    shiny::validate(
      need(!is.null(get_finam_data(input$symb, from=input$date, to = input$date, period = input$period)), "Not A Valid Stock Symbol (No Market Data)")
    )
    
    prices <- get_finam_data(input$symb, from = input$date, to = input$date, period = input$period) %>%

      # Used to filter for only open-market hours because data is 24 hour time value
      
      mutate(since_midnight = hour(time) * 60 + minute(time)) %>% 
      filter(since_midnight >= 9*60 & since_midnight <= (16 * 60)) %>% 
      select(time,open, high,low,close)
    

  })
  
  volumeInput <- reactive({
    
    shiny::validate(
      need(as.logical(isWeekday(input$date)) == TRUE , "Please select a valid weekday")
    )
    
    shiny::validate(
      need(!is.null(get_finam_data(input$symb, from=input$date, to = input$date, period = input$period)), "Not A Valid Stock Symbol (No Market Data)")
    )
    
    volume <- get_finam_data(input$symb, from = input$date, to = input$date, period = input$period) %>% 
      mutate(since_midnight = hour(time) * 60 + minute(time)) %>% 
      filter(since_midnight >= 9*60 & since_midnight <= (16 * 60)) %>% 
      select(time,volume)
  })
  
  # Plot dygraph output for price. Must first data convert to xts to make it a valid dygraph input.
  # order.by indexes each row by time for the time series data. We then drop the time column value because
  # rows are now indexed by time and the column is necessary.
  
  # dyrangeSelector allows for interactive zoomingi in on the data. dyCandlestick is an
  # add-ons that creates an easier and more commone visualization of the stock market data 
  # (as opposed to line chart) We set useDataTimezone = TRUE because all data should reflect U.s. market hours,
  # not the application user's timezone.
  
  output$price <- renderDygraph({
    
    prices <- priceInput()
    prices_xts <- xts(prices, order.by = prices$time)
    prices_xts$time <- NULL
    dygraph(prices_xts, main = paste(input$symb, input$date)) %>% 
    dyCandlestick() %>% 
    dyRangeSelector() %>% 
    dyOptions(useDataTimezone = TRUE)
  })

  # Same principles output$price, but we add the stepPlot graph for a more intuitive trading volume
  # visualization
  
  output$volume <- renderDygraph({
    
    volume <- volumeInput()
    volume_xts <- xts(volume, order.by = volume$time)
    volume_xts$time <- NULL
    dygraph(volume_xts, main = paste(input$symb, input$date)) %>% 
    dyOptions(stepPlot = TRUE, fillGraph = TRUE, colors="blue", useDataTimezone = TRUE)

  })
  
  # DTable of Trumps tables. Filters based on the text containing the input$keyword. 
  # Selection = "single" allows only one row (and date cell) to be selected at a time
  # Format style ise used to change the cursor to a more click-friendly pointer over the date column
  # list(dom = "tip") gets rid of the defualt search bar that comes with DTables
  
  output$word_table <- renderDT({
    
    datatable(tweets %>% filter(str_detect(text, input$keyword)) ,
    class = 'display',
    rownames = FALSE,
    selection = 'single',
    colnames = c('Tweet Text', 'Date', 'Time', 'Retweets', 'Favorites'),
    options = list(dom = 'tip')
    ) %>% formatStyle(2, cursor = 'pointer')
  })
  
  ###################################
  # KEYWORDS PAGE 
  ###################################
  
  
  # Reactive DataFrame that changes based on event listener below
  
  type <- reactiveValues(data_frame=NULL)
  
  observeEvent(input$type, {
    
    # Example: if input$type (from inputSelectionisCompany, use company data frame
    # Same logic applies for country and individual
    
    if(input$type == "Company"){
    type$data_frame <- company
    }
    
    if(input$type == "Country"){
      type$data_frame <- country
    }
    
    if(input$type == "Individual"){
      type$data_frame <- individual
    }
    
  })
  
  # Outputs positive sentiment bar chart for key words by filtering for sentiment == "positive"

  
  output$positive <- renderPlot({
    positive <- type$data_frame %>% 
      filter(sentiment == "positive")
    
    # Scale_y_continuous used to format plot padding. 
    # "Bg=transparent" argument creates transparent plot that is nicer visually. 
   
    ggplot(positive, aes(x = reorder(keyword, -n), y = n)) +
      geom_bar(position ="dodge", stat="identity", fill="palegreen3") +
      scale_y_continuous(expand = c(0,0), limits = c(0, max(positive[,3]) + max(positive[,3])/10)) +
      coord_flip() +
      labs(x=NULL, y=NULL) +
      theme(
            axis.text.x = element_text(size = 15),
            axis.text.y = element_text(size = 15),
            panel.background= element_blank(),
            plot.background = element_blank()
      ) +
    theme_hc()
    }, bg="transparent")
  
  # Outputs positive sentiment bar chart for key words by filtering for sentiment == "positive"
  # Color change to signify negative sentiment
  
  output$negative <- renderPlot({
      negative <- type$data_frame %>% 
        filter(sentiment == "negative")
      
      ggplot(negative, aes(x = reorder(keyword, -n), y = n)) +
      geom_bar(position ="dodge", stat="identity", fill="firebrick4") +
      scale_y_continuous(expand = c(0,0), limits = c(0, max(negative[,3]) + max(negative[,3])/10)) +
      coord_flip() +
      labs(x=NULL, y=NULL) +
      theme(
        axis.text.x = element_text(size = 15),
        axis.text.y = element_text(size = 15),
        panel.background= element_blank(),
        plot.background = element_blank()
      ) +
      theme_hc()
  },bg="transparent")
  
  
})

# Run the application 
shinyApp(ui = ui, server = server)


